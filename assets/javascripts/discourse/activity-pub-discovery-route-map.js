export default function () {
  this.route(
    "activityPub.actor",
    {
      path: "/ap/local/actor/:actor_id",
      resetNamespace: true,
    },
    function () {
      this.route("followers");
      this.route("follows");
    }
  );
}
