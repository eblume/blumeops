import React from "react";

export function Panel(props: { load: () => void }) {
  const refresh = () => {
    try {
      props.load();
    } catch (err) {
      console.log("panel load failed", err);
    }
  };
  return <button onClick={refresh}>Refresh</button>;
}
