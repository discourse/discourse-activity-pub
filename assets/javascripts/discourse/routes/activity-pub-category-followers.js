import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseRoute from "discourse/routes/discourse";
import Category from "discourse/models/category";

export default DiscourseRoute.extend({
  queryParams: {
    order: { refreshModel: true },
    asc: { refreshModel: true },
    domain: { refreshModel: true },
    username: { refreshModel: true }
  },

  model(params) {
    const category = Category.findById(params.category_id);

    return ajax(`/ap/category/${category.id}/followers.json`)
      .then(response => ({ category, ...response }))
      .catch(popupAjaxError);
  },

  setupController(controller, model) {
    controller.setProperties(model);
  },
});
