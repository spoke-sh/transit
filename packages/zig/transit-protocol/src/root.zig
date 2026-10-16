//! Transit v1 wire contract. All callers use this single current definition.
const std = @import("std");
pub const version = 1;
pub const Value = @import("Value.zig");
pub const Ed25519 = std.crypto.sign.Ed25519;
pub const Json = @import("Json.zig");
pub const Schema = @import("Schema.zig");
pub const Diagnostic = @import("Diagnostic.zig");
pub const Runtime = @import("Runtime.zig");
pub const State = @import("State.zig");
pub const Authorization = @import("Authorization.zig");
pub const Growth = @import("Growth.zig");
pub const Inspection = Growth.Inspection;
pub const Lifecycle = @import("Lifecycle.zig");
pub const max_effect_observations = 16;
pub const max_payload_bytes = 64 * 1024;
pub const max_turn_outputs = Growth.turn_outputs;
pub const max_counter = (1 << 53) - 1;
pub const max_admission_ceiling = 65536;
pub const max_control_reserve = 65536;
pub const max_entry_bytes = 8192;
pub const max_body = 256 * 1024;
pub const Permission = enum(u4) { admin, spawn, send, execute, inspect, effect, publish, delivery };
pub const all_permissions: u16 = 0xff;
pub fn permission(value: Permission) u16 {
    return @as(u16, 1) << @backingInt(value);
}
pub const PayloadRef = struct { pid: u64, payload: u64 };
pub const Receipt = struct { position: u64 };
pub const Grant = Growth.Grant;
pub const Process = Growth.Process;
pub const Effect = Growth.Effect;
pub const EffectDiagnostic = @import("EffectDiagnostic.zig");
pub const Output = Growth.Output;
pub const Payload = Growth.Payload;
pub const Outbox = Growth.Outbox;
pub const Turn = Growth.Turn;
pub const Command = Growth.Command;
pub const Request = Growth.Request;
pub const SignedRequest = Growth.SignedRequest;
pub const Origin = Growth.Origin;
pub const Input = Growth.Input;
pub const Query = Growth.Query;
pub const SignedQuery = Growth.SignedQuery;
pub const Response = Growth.Response;
pub const validate = Growth.validate;
pub const digest = Growth.digest;
pub const sign = Growth.sign;
test {
    _ = Json;
    _ = Schema;
    _ = Growth;
    _ = Value;
    _ = Diagnostic;
    _ = EffectDiagnostic;
    _ = Authorization;
}

/// Stable wire rejection codes. Unknown internal failures map to AuthorityUnavailable.
pub const ErrorCode = enum {
    AuthorizationSubjectDenied,
    AuthorizationBudgetExceeded,
    AuthorizationChangeQuota,
    AuthorizationIdentityExhausted,
    AuthorizationNameExists,
    AuthorizationCredentialExists,
    AuthorizationDependencies,
    InvalidAuthorizationBudget,
    InvalidAuthorizationName,
    InvalidAuthorizationRole,
    InvalidAuthorizationObject,
    InvalidAuthorizationDomain,
    InvalidAuthorizationGrant,
    InvalidAuthorizationPrivilege,
    InvalidAuthorizationRevision,
    InvalidAuthorizationCredential,
    InvalidAuthorizationChange,
    InvalidAuthorizationCursor,
    InvalidRoleMembership,
    RetiredAuthorizationRole,
    RetiredAuthorizationObject,
    RoleMembershipCycle,
    StaleAuthorizationRevision,
    StaleAuthorizationCredential,
    UnknownAuthorizationRole,
    UnknownAuthorizationObject,
    UnknownAuthorizationGrant,
    UnknownAuthorizationChange,
    UnknownRoleMembership,
    HttpCapacity,
    InvalidLifecycle,
    MissingRequiredAssociation,
    NotInitialized,
    SuspendedProcess,
    NoPendingOutput,
    InvalidStateKey,
    InvalidStateMutation,
    InvalidStateView,
    StaleAssociation,
    StaleStateResource,
    StateAssociationCapacity,
    StateEntryCapacity,
    StateResourceCapacity,
    StateResourceExpired,
    StateResourceInUse,
    StateViewCapacity,
    StateViewExpired,
    StateViewInUse,
    UnknownStateResource,

    AccessDenied,
    AdmissionClosed,
    AlreadyActivated,
    AttemptAlreadyAuthorized,
    AuthorityUnavailable,
    BindingReplacementUnsupported,
    BlockedProcess,
    ClockRollback,
    ClockUnavailable,
    Conflict,
    ConflictingRetry,
    ControlAlreadyRecorded,
    ControlCapacity,
    DeadlineExpired,
    DeadlineNotReached,
    DeadlineUncertain,
    DependencyBudgetExceeded,
    DependencyInUse,
    EffectCapacity,
    Forbidden,
    FreshKeyRequired,
    HistoryPinned,
    HistoryReclaimed,
    QueryExpired,
    IdentityElement,
    InvalidAttempt,
    InvalidBinding,
    InvalidBody,
    InvalidBudget,
    InvalidEffect,
    InvalidEncoding,
    InvalidFailure,
    InvalidGrant,
    InvalidInput,
    InvalidLifetime,
    InvalidOutput,
    InvalidPayload,
    InvalidRead,
    InvalidReadVersion,
    UnknownReadVersion,
    ReadVersionReleased,
    InvalidRequest,
    InvalidSequence,
    InvalidTurnPermit,
    InvalidValue,
    MissingInput,
    MissingTurnPermit,
    MissingWriteView,
    NoDeadline,
    NonCanonical,
    NotFound,
    OutputAlreadyResolved,
    OutputCapacity,
    Overflow,
    PayloadCapacity,
    PayloadInUse,
    PayloadPhase,
    PendingProviderOperation,
    PendingWork,
    ProcessCapacity,
    ProviderIncarnationMismatch,
    ProviderNotReady,
    ProviderOperationClosed,
    ReconciliationClosed,
    ResourceAlreadyBound,
    RetentionNotEnabled,
    RetiredProcess,
    RetryHorizonExceeded,
    RouteBlocked,
    RuntimeActivationRequired,
    SequenceGap,
    SignatureVerificationFailed,
    StaleBinding,
    StaleGeneration,
    StaleState,
    StaleWorkerIncarnation,
    TurnAlreadyAuthorized,
    Unauthorized,
    UnknownEffect,
    UnknownOutput,
    UnknownPayload,
    UnknownPrincipal,
    UnknownProcess,
    UnsupportedDeadline,
    UnsupportedGrowthCommand,
    UnsupportedPayloadLifetime,
    UnsupportedWorkload,
    UntrustedTime,
    WrongProtocolRealm,
};
pub const ErrorResponse = struct { err: ErrorCode };
