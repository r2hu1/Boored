import { writeFileSync } from "node:fs";
import { createApp } from "../app.js";

async function main() {
  const app = createApp();
  const res = await app.request("/v1/openapi.json");
  const spec = await res.json();
  const outPath = "../../packages/contracts/openapi.json";
  writeFileSync(outPath, JSON.stringify(spec, null, 2));
  console.log(`OpenAPI spec exported to ${outPath}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
