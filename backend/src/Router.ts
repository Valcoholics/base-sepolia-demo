import { ponder } from "@/generated";

ponder.on("Router:FactoryRegistered", async ({ event, context }) => {
  console.log(event.args);
});

ponder.on("Router:OwnershipTransferred", async ({ event, context }) => {
  console.log(event.args);
});
