export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("activityPub", { path: "/ap" }, function () {
      this.route("actor");
      this.route("actorShow", { path: "/actor/:actor_id" });
      this.route("log");
    });
  },
};
