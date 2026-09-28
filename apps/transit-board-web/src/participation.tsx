import { useEffect, useState } from "react";
import {
  BoardError,
  participation,
  type ParticipationResponse,
  type ParticipationCursor,
} from "@rey/transit-board-client";
import { message } from "./state";
/** A bounded projection, never a second registry or an activity measurement. */
export function Participation({ resource }: { resource: number }) {
  const [cursor, setCursor] = useState<ParticipationCursor>({});
  const [revision, refresh] = useState(0);
  const [data, setData] = useState<ParticipationResponse | null>(null);
  const [error, setError] = useState("");
  useEffect(() => {
    const abort = new AbortController();
    let reading = false;
    let timer: ReturnType<typeof setTimeout>;
    async function read() {
      if (abort.signal.aborted || document.hidden || reading) return;
      reading = true;
      try {
        let next: ParticipationResponse;
        for (let attempt = 0; ; attempt++) {
          try {
            next = await participation(resource, cursor, abort.signal);
            break;
          } catch (cause) {
            if (
              !(cause instanceof BoardError) ||
              cause.status !== 429 ||
              attempt >= 3 ||
              abort.signal.aborted
            )
              throw cause;
            await new Promise((resolve) => setTimeout(resolve, 250));
          }
        }
        if (!abort.signal.aborted && !document.hidden) {
          setData(next);
          setError("");
        }
      } catch (cause) {
        if (!abort.signal.aborted) {
          setData(null);
          setError(message(cause));
        }
      } finally {
        reading = false;
        if (!abort.signal.aborted) timer = setTimeout(() => void read(), 5000);
      }
    }
    const visibility = () => {
      clearTimeout(timer);
      if (document.hidden) setData(null);
      else void read();
    };
    setData(null);
    void read();
    document.addEventListener("visibilitychange", visibility);
    return () => {
      clearTimeout(timer);
      abort.abort();
      document.removeEventListener("visibilitychange", visibility);
    };
  }, [resource, cursor, revision]);
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
