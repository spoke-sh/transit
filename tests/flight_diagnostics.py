"""Actual saved arithmetic failure, exact Flight retry and ADBC propagation."""
import subprocess
import time


def verify(context):
    import pyarrow as pa
    import pyarrow.flight as flight
    import adbc_driver_flightsql as adbc
    from adbc_driver_flightsql import dbapi
    from flight_detail import Details, adbc_diagnostic
    client = context['client']
    details = context['details']
    statement = context['descriptor'](context['sql'].CommandStatementQuery(query='SELECT SUM(value) FROM items'))
    options = context['call_options'](2)

    def failure():
        deadline = time.monotonic() + 180
        while True:
            try:
                client.get_flight_info(statement, options)
            except flight.FlightUnavailableError:
                # Repeat only the identical statement and first sequence.
                assert time.monotonic() < deadline
                time.sleep(.1)
            except pa.ArrowException as error:
                message = str(error)
                assert 'query.arithmetic_overflow execution #2' in message, message
                assert 'result or service unavailable' not in message
                detail = details.diagnostic()
                assert detail['code'] == 'query.arithmetic_overflow' and detail['outcome'] == 'rejected', detail
                assert detail['identity']['id'] == '2' and detail['evidence'] == 'domain_status'
                facts = {fact['field']:fact['value'] for fact in detail['facts'] if fact}
                assert facts['operation'] == {'text':'sum'} and facts['column'] == {'text':'value'}, detail
                assert facts['completion'] == {'boolean':False} and 'source_basis' in facts, detail
                return message,detail
            else:
                raise AssertionError('overflowing SUM returned FlightInfo')

    first = failure()
    assert failure() == first
    context['process'].kill()
    context['process'].wait(timeout=5)
    context['start']('gateway-diagnostic-replacement', [context['gateway'], str(context['gateway_config'])])
    client.close()
    details = Details()
    client = flight.connect(context['uri'], tls_root_certs=context['certificate'], middleware=[details])
    assert failure() == first
    with dbapi.connect(context['uri'], db_kwargs={
        adbc.DatabaseOptions.AUTHORIZATION_HEADER.value: 'Bearer ' + context['token'],
        adbc.DatabaseOptions.TLS_ROOT_CERTS.value: context['certificate'].decode(),
    }, autocommit=True) as connection:
        with connection.cursor() as cursor:
            cursor.adbc_statement.set_options(**{adbc.StatementOptions.RPC_CALL_HEADER_PREFIX.value + 'x-transit-request-sequence': '2'})
            try:
                cursor.execute('SELECT SUM(value) FROM items')
            except dbapi.DatabaseError as error:
                assert 'query.arithmetic_overflow execution #2' in str(error), error
                assert adbc_diagnostic(error) == first[1], error.details
            else:
                raise AssertionError('ADBC replaced the saved failure with a result')
    subprocess.run([context['proof'], context['url'], 'revoke', str(context['fixture'].root / 'cli.json')], check=True, capture_output=True, timeout=30)
    try:
        client.get_flight_info(statement, options)
    except flight.FlightUnauthorizedError as error:
        assert 'query.arithmetic_overflow' not in str(error)
        denied = details.diagnostic()
        assert denied['category'] == 'access' and denied['outcome'] == 'not_applicable'
        assert denied['identity'] is None, denied
        assert [fact for fact in denied['facts'] if fact] == [{
            'field': 'operation', 'origin': 'caller', 'availability': 'provided',
            'value': {'text': 'Flight RPC'},
        }], denied
    else:
        raise AssertionError('retained diagnostic disclosed after current access was revoked')
    client.close()
    print('Flight/ADBC saved diagnostics: original checked overflow, exact retry, gateway replacement and current-disclosure denial passed.', flush=True)
