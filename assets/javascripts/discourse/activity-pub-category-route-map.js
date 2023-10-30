export default function() {
  this.route("activityPub.category.followers", {
    path: "/ap/category/:category_id/followers"
  });
};