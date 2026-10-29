//! Shared refusal classification for HTTP and typed local owner dispatch.
const std = @import("std");
const p = @import("transit_client").protocol;
pub fn table(err: anyerror) p.ErrorCode {
    return switch (err) {
        error.InvalidBody => .InvalidBody,
        error.InvalidRequest => .InvalidRequest,
        error.CatalogDenied, error.TableDelegationDenied, error.InvalidAuthorizationCredential, error.AuthorizationChanged, error.TransactionAuthorityChanged => .AccessDenied,
        error.TableDefinitionChanged => .TableDefinitionChanged,
        error.StaleClientLease, error.ClientTokenConflict, error.ClientBudgetConflict, error.ClientOperationConflict, error.ClientOperationPending, error.TransactionCatalogChanged, error.TransactionConflict, error.TransactionIdentityConflict, error.TransactionPrepared, error.TransactionFrozen, error.TransactionStatementConflict, error.TransactionStatementPending, error.TransactionControlPending, error.TransactionControlConflict, error.TransactionReadConflict, error.TransactionWriteConflict => .Conflict,
        error.ClientTokenCapacity, error.TransactionCapacity, error.TransactionAccountCapacity, error.TransactionMemoryLimit, error.TransactionWorkspaceLimit, error.TransactionStatementLimit, error.TransactionSavepointLimit, error.TransactionControlLimit => .StorageQuota,
        error.TransactionOperationRequired, error.InvalidTransactionBegin, error.InvalidTransactionDirectory, error.InvalidTransactionLimits, error.MissingTransactionDirectory, error.UnsupportedTransactionParticipant, error.ReadOnlyTransaction, error.InvalidTransactionWork, error.TransactionObjectNotSelected, error.TransactionCutNotAcquired, error.InvalidTransactionRead, error.UnsupportedTransactionRead, error.InvalidTransactionSavepoint, error.TransactionSavepointMissing => .InvalidRequest,
        error.SourceChanged, error.DataIdentityConflict, error.CatalogObjectBusy, error.CatalogObservationChanged, error.TableDataChanged, error.TableHistoryConflict, error.NamedResourceNotAdmitted, error.NamedResourceAllocationUnreconciled, error.NamedResourceAllocationMismatch, error.NamedResourceIdentityConflict, error.NativeAllocationSequenceChanged, error.NativeAllocationBusy => .Conflict,
        error.TableSnapshotReleased, error.TableSnapshotNotPinned, error.TransactionReadChanged => .QueryExpired,
        error.TableHistoryMissing, error.WalHistoryMissing, error.WalHistoryTrimmed => .HistoryReclaimed,
        error.InvalidTableBasis, error.TableHistoryRetentionRequired, error.IncompatibleColumnEncoding, error.IncompatibleColumnCollation, error.UnsupportedColumnCollation, error.IbmHfpUnderflow, error.IbmHfpOverflow, error.UnrepresentableEbcdic037 => .InvalidRequest,
        error.ClientOperationMissing, error.InvalidDirectRecord, error.DirectRecordMissing, error.InvalidClientToken, error.InvalidPlanEncoding, error.InvalidProjection, error.InvalidTableBinary, error.TablePayloadTooLarge, error.InvalidTableMutationIntent, error.InvalidInsertRowIdentity, error.InvalidTableStatementIntent, error.InvalidTableAccessRequest, error.InvalidMutationPlan, error.MutationBatchTooLarge, error.UnsupportedTableMutationShape, error.TableBatchTooLarge, error.InvalidTableReadBudget, error.InvalidTableCursor, error.InvalidTableSnapshotCursor, error.TableReadBudgetTooSmall, error.InvalidTableKey, error.TableSchemaChanged => .InvalidRequest,
        else => native(err),
    };
}
pub fn native(err: anyerror) p.ErrorCode {
    return switch (err) {
        error.Unauthorized, error.Forbidden, error.WrongProtocolRealm, error.SignatureVerificationFailed, error.IdentityElement, error.NonCanonical, error.InvalidEncoding, error.UnknownAuthorizationRole, error.UnknownAuthorizationObject, error.UnknownAuthorizationGrant, error.UnknownAuthorizationChange, error.UnknownRoleMembership, error.RetiredAuthorizationRole, error.RetiredAuthorizationObject, error.InvalidAuthorizationDomain => .AccessDenied,
        else => std.meta.stringToEnum(p.ErrorCode, @errorName(err)) orelse .AuthorityUnavailable,
    };
}
pub fn status(code: p.ErrorCode) std.http.Status {
    return switch (code) {
        .AccessDenied => .forbidden,
        .NotFound => .not_found,
        .InvalidRequest, .InvalidBody => .bad_request,
        .Conflict, .TableDefinitionChanged, .QueryExpired, .HistoryReclaimed, .StaleAuthorizationRevision, .StaleAuthorizationCredential, .AuthorizationSubjectDenied => .conflict,
        .AuthorityUnavailable, .ClockRollback, .ClockUnavailable, .DeadlineUncertain, .UntrustedTime, .AdmissionClosed, .ControlCapacity, .StorageQuota => .service_unavailable,
        else => .unprocessable_entity,
    };
}
