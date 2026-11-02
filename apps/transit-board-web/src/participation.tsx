import { useState } from "react";
import { BoardError, participation, type ParticipationCursor } from "@transit/board-client";
import { message } from "./state";
import { useRead } from "./use-observation";
/** A bounded projection, never a second registry or an activity measurement. */
export function Participation({ resource }: { resource: number }) {
  const [cursor, setCursor] = useState<ParticipationCursor>({});
  const [revision, refresh] = useState(0);
  const state = useRead(JSON.stringify(["participation", resource, cursor, revision]), (signal) =>
    participation(resource, cursor, signal),
  );
  const data = state.value;
  const error = state.failure ? message(new BoardError(0, state.failure.code)) : "";
  const members = data?.members.filter((member) => member !== null) ?? [];
  return (
    <section className="participation" aria-label="Resource participation">
      <h3>Shared-resource participation</h3>
      <p role="status">
        {error ||
          (data
            ? `${members.filter((member) => member.matches > 0).length} visible participants on these association pages`
            : "Reading authorized associations…")}
      </p>
      <p>
        At most eight processes and eight associations per process. Each page has its own basis;
        counts do not measure traffic or a complete realm.
      </p>
      {data && (
        <>
          <p>
            Resource observed at {data.resource_position}.{" "}
            {data.process_position === null
              ? "One selected PID."
              : `Process page at ${data.process_position}.`}
          </p>
          <div className="table-scroll">
            <table>
              <caption>Authorized associations to resource {resource}</caption>
              <thead>
                <tr>
                  <th>PID</th>
                  <th>On this page</th>
                  <th>Evidence</th>
                </tr>
              </thead>
              <tbody>
                {members.map((member) => (
                  <tr key={member.pid}>
                    <td>{member.pid}</td>
                    <td>{member.matches}</td>
                    <td>
                      Position {member.association_position}
                      <br />
                      {member.next === null ? (
                        "End of PID association scan"
                      ) : (
                        <button
                          onClick={() =>
                            setCursor({
                              pid: member.pid,
                              association_after: member.next!,
                              position: member.association_position,
                            })
                          }
                        >
                          Next associations for PID {member.pid}
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {data.next !== null && (
            <button
              onClick={() => setCursor({ after: data.next!, position: data.process_position! })}
            >
              Next participant process page
            </button>
          )}
        </>
      )}
      <button
        onClick={() => {
          setCursor({});
          refresh((value) => value + 1);
        }}
      >
        Refresh participation
      </button>
      <p>
        Association and resource observations are independent of Atlas. Association does not confer
        ownership, permission or readiness.
      </p>
    </section>
  );
}
