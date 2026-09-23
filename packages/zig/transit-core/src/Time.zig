//! Trusted authority time, never a timestamp supplied by a workload request.
//! A source asserts that UTC lies in [unix_ms - error_ms, unix_ms + error_ms].
//! Missing/unsynchronized sources fail closed for time-dependent operations.
pub const Sample = struct {
    unix_ms: u64,
    error_ms: u32 = 0,

    pub fn lower(self: Sample) u64 {
        return self.unix_ms -| self.error_ms;
    }
    pub fn upper(self: Sample) u64 {
        return self.unix_ms +| self.error_ms;
    }
    pub fn before(self: Sample, deadline: u64) !void {
        if (self.lower() >= deadline) return error.DeadlineExpired;
        if (self.upper() >= deadline) return error.DeadlineUncertain;
    }
    pub fn after(self: Sample, deadline: u64) !void {
        if (self.lower() < deadline) return error.DeadlineNotReached;
    }
};

pub const Source = struct {
    context: *anyopaque,
    read: *const fn (*anyopaque) anyerror!Sample,

    pub fn sample(self: Source) !Sample {
        return self.read(self.context);
    }
};
