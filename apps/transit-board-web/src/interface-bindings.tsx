import { useInterface } from "./interface";
export function InterfaceBindings() {
  const current = useInterface();
  return (
    <section aria-label="Interface bindings">
      {current && (
        <>
          <h2>Interface bindings</h2>
          <p>
            Declarations identify intended sources and targets. They do not grant access or confirm
            resource liveness.
          </p>
          <div className="table-scroll">
            <table>
              <caption>
                Bindings in {current.compiled.definition.name} revision{" "}
                {current.compiled.definition.revision}
              </caption>
              <thead>
                <tr>
                  <th>Binding</th>
                  <th>Kind</th>
                  <th>Reference</th>
                </tr>
              </thead>
              <tbody>
                {current.compiled.definition.bindings.map((binding) => (
                  <tr key={binding.name}>
                    <td>{binding.name}</td>
                    <td>{Object.keys(binding.source)[0]}</td>
                    <td>
                      {"inspection" in binding.source
                        ? binding.source.inspection.projection
                        : "query" in binding.source
                          ? `Resource ${binding.source.query.resource} · ${binding.source.query.source_kind} · ${binding.source.query.profile}`
                          : `Service ${binding.source.command.service} · target ${binding.source.command.target} · revision ${binding.source.command.revision}`}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </>
      )}
    </section>
  );
}
