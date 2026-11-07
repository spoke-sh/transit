//! Component caller for an explicitly configured trusted capture host. Native
//! services intentionally install only CaptureReader; no public mutation route.
const c = @import("transit_catalog");
const capture = c.DirectSourceCapture;
const Self = @This();
catalog: *c.DirectCatalog,
policy: c.DirectCatalog.Policy,
authority: capture.Authority,

pub fn reserve(self: Self, descriptor: capture.Descriptor) !capture.Observation {
    return self.catalog.captureReserve(descriptor, self.policy, self.authority);
}
pub fn inspect(self: Self, lookup: capture.Lookup) !?capture.Observation {
    return self.catalog.captureInspect(lookup, self.policy, self.authority);
}
pub fn upload(self: Self, request: capture.Upload) !capture.Observation {
    return self.catalog.captureUpload(request, self.policy, self.authority);
}
pub fn verify(self: Self, verifier: *capture.Verifier, work: capture.StepBudget) !capture.Observation {
    return self.catalog.captureVerify(verifier, work, self.policy, self.authority);
}
pub fn publish(self: Self, publication: c.DirectSourcePublication) !capture.Observation {
    return self.catalog.capturePublish(publication, self.policy, self.authority);
}
pub fn advance(self: Self, key: c.DirectClientToken.Key, command: c.DirectTransactionControl.Command, steps: u16) !capture.Observation {
    return self.catalog.captureAdvance(key, command, steps, self.policy, self.authority);
}
pub fn close(self: Self, control: capture.Control) !capture.Observation {
    return self.catalog.captureClose(control, self.policy, self.authority);
}
