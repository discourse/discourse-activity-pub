import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseRoute from "discourse/routes/discourse";

export default class ActivityPubAboutRoute extends DiscourseRoute {
  model() {
    return ajax("/ap/about.json").catch(popupAjaxError);
  }

  setupController(controller, model) {
    controller.setProperties({
      categoryActors: model.category_actors,
      tagActors: model.tag_actors,
    });
  }
}
