"""Real mutation ABI and port callers; all protocol semantics remain in Zig."""
import ctypes as c
import json
from pathlib import Path
import select
import subprocess
from unified_abi import Failure


class Native:
    def __init__(self, library, url, connection):
        self.api = api = c.CDLL(str(Path(library).resolve()))
        api.station_table_mutation_create.argtypes = [c.c_uint32,c.c_char_p,c.c_size_t,c.c_void_p,c.c_char_p,c.c_size_t,c.POINTER(c.c_void_p)]
        api.station_table_mutation_create.restype = c.c_uint32
        api.station_table_mutation_call.argtypes = [c.c_void_p,c.c_char_p,c.c_size_t,c.POINTER(c.c_void_p)]
        api.station_table_mutation_call.restype = c.c_uint32
        api.station_table_mutation_destroy.argtypes = [c.c_void_p]
        api.station_table_mutation_destroy.restype = None
        api.station_buffer_data.argtypes = [c.c_void_p]
        api.station_buffer_data.restype = c.c_void_p
        api.station_buffer_size.argtypes = [c.c_void_p]
        api.station_buffer_size.restype = c.c_size_t
        api.station_buffer_destroy.argtypes = [c.c_void_p]
        api.station_buffer_destroy.restype = None
        self.pointer = c.c_void_p()
        endpoint = url.encode()
        config = json.dumps(dict(connection=connection,timeout_ms=10000)).encode()
        seed = c.create_string_buffer(bytes([10])*32,32)
        status = api.station_table_mutation_create(1,endpoint,len(endpoint),seed,config,len(config),c.byref(self.pointer))
        assert status == 0

    def call(self, action):
        request = json.dumps(action).encode()
        pointer = c.c_void_p()
        status = self.api.station_table_mutation_call(self.pointer,request,len(request),c.byref(pointer))
        try:
            value = json.loads(c.string_at(self.api.station_buffer_data(pointer),self.api.station_buffer_size(pointer))) if pointer.value else None
        finally:
            self.api.station_buffer_destroy(pointer)
        if status: raise Failure(status,value)
        return value

    def close(self):
        if self.pointer.value:
            self.api.station_table_mutation_destroy(self.pointer)
            self.pointer = c.c_void_p()


class Port:
    def __init__(self, host, root, url, connection):
        config = root/'mutation-client-port.json'
        config.write_text(json.dumps(dict(url=url,seed_file=str(root/'caller.seed'),mutation_client=dict(connection=connection,timeout_ms=10000))))
        self.child = subprocess.Popen([host,str(config)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,bufsize=0)

    def call(self, action):
        self.child.stdin.write(json.dumps({'table_mutation':action}).encode()+b'\n')
        assert select.select([self.child.stdout],[],[],20)[0], 'Mutation port timed out'
        line = self.child.stdout.readline(540672)
        assert line.endswith(b'\n'), 'Incomplete mutation response'
        result = json.loads(line)
        if result['status']: raise Failure(result['status'],result['value'])
        return result['value']

    def close(self):
        self.child.stdin.close()
        try:
            assert self.child.wait(timeout=10) == 0
        finally:
            if self.child.poll() is None:
                self.child.kill(); self.child.wait(timeout=5)
            self.child.stdout.close()


def check_profiles(host, root, url, connection):
    mutation = dict(connection=connection,timeout_ms=10000)
    query = dict(connection=dict(realm=46,principal=1234,source=1,resource=1,requester=2,requests=2),timeout_ms=10000)
    for name,config in (
        ('local',dict(local_codec=True,mutation_client=mutation)),
        ('mixed',dict(url=url,seed_file=str(root/'caller.seed'),query_client=query,mutation_client=mutation)),
    ):
        path = root/f'conflicting-{name}.json'
        path.write_text(json.dumps(config))
        child = subprocess.run([host,str(path)],capture_output=True,text=True,timeout=15)
        assert child.returncode != 0 and 'ConflictingHostProfiles' in child.stderr, (name,child.stderr)
    path = root/'read-query-profile.json'
    path.write_text(json.dumps(dict(url=url,seed_file=str(root/'caller.seed'),query_client=query)))
    result = subprocess.run([host,str(path)],input='{"table_mutation":{"capabilities":{}}}\n{"shutdown":{}}\n',capture_output=True,text=True,timeout=15)
    assert result.returncode == 0, result.stderr
    replies = [json.loads(line) for line in result.stdout.splitlines()]
    assert replies == [dict(status=13,value=None),dict(status=0,value=dict(closed=True))], replies
