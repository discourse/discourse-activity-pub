import EmberObject from "@ember/object";
import { notEmpty } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const ActivityPubCategory = EmberObject.extend({
  hasActors: notEmpty("actors"),

  loadMore() {
    if (!this.loadMoreUrl || this.total <= this.actors.length) {
      return;
    }

    this.set("loadingMore", true);

    return ajax(this.loadMoreUrl)
      .then((response) => {
        if (response) {
          this.actors.pushObjects(response.actors);
          this.setProperties({
            loadMoreUrl: response.meta.load_more_url,
            loadingMore: false,
          });
        }
      })
      .catch(popupAjaxError);
  },
});

ActivityPubCategory.reopenClass({
  listActors(categoryId, params, listType) {
    const queryParams = new URLSearchParams();

    if (params.order) {
      queryParams.set("order", params.order);
    }

    if (params.asc) {
      queryParams.set("asc", params.asc);
    }

    const path = `/ap/category/${categoryId}/${listType}`;

    let url = `${path}.json`;
    if (queryParams.size) {
      url += `?${queryParams.toString()}`;
    }

    return ajax(url).catch(popupAjaxError);
  },
});

export default ActivityPubCategory;
