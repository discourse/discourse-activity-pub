export default {
  resource: "admin",
  map() {
    this.route(
      "adminActivityPub",
      {
        path: "/ap",
        resetNamespace: true,
      },
      function () {
        this.route("adminActivityPubActor", {
          path: "/actor",
          resetNamespace: true,
        });
        this.route("adminActivityPubActorShow", {
          path: "/actor/:actor_id",
          resetNamespace: true,
        });
      }
    );
  },
};
