import { useId, useState } from "react";
import { formatBytes, type ByteCount } from "./quantities";
import "./quantity.css";

export function ExactBytes({ value, label = "Exact size" }: { value: ByteCount; label?: string }) {
  const exact = formatBytes(value).exact;
  const [copy, setCopy] = useState<{ exact: string; message: string } | null>(null);
  return (
    <span className="quantity-detail">
      <span>
        {label}: {BigInt(exact).toLocaleString()} bytes
      </span>{" "}
      <button
        type="button"
        onClick={() => {
          void navigator.clipboard?.writeText(exact).then(
            () => setCopy({ exact, message: "Exact bytes copied." }),
            () => setCopy({ exact, message: "Copy unavailable. Select the exact value to copy." }),
          );
          if (!navigator.clipboard)
            setCopy({ exact, message: "Copy unavailable. Select the exact value to copy." });
        }}
      >
        Copy exact bytes
      </button>
      <span role="status">{copy?.exact === exact ? copy.message : ""}</span>
    </span>
  );
}

/** Inline disclosure works inside text and table cells, without hover or another dock. */
export function ByteSize({ value }: { value: ByteCount | null | undefined }) {
  const [open, setOpen] = useState(false);
  const id = useId();
  if (value == null) return <>Unavailable</>;
  const quantity = formatBytes(value);
  return (
    <span className="quantity">
      <button
        type="button"
        className="quantity-value"
        aria-expanded={open}
        aria-controls={id}
        aria-label={`${quantity.accessible}; exact size`}
        onClick={() => setOpen(!open)}
      >
        {quantity.text}
      </button>
      <span id={id} hidden={!open}>
        {open && <ExactBytes value={value} />}
      </span>
    </span>
  );
}
