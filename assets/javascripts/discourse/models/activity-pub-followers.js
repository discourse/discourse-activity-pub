import EmberObject from "@ember/object";
import { notEmpty } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

class ActivityPubFollowers extends EmberObject {
  @notEmpty("followers") hasFollowers;

  loadMore() {
    if (!this.loadMoreUrl || this.total <= this.followers.length) {
      return;
    }

    this.set("loadingMore", true);

    return ajax(this.loadMoreUrl)
      .then((response) => {
        if (response) {
          this.followers.pushObjects(response.followers);
          this.setProperties({
            loadMoreUrl: response.meta.load_more_url,
            loadingMore: false,
          });
        }
      })
      .catch(popupAjaxError);
  }
}

ActivityPubFollowers.reopenClass({
  load(category, params) {
    const queryParams = new URLSearchParams();

    if (params.order) {
      queryParams.set("order", params.order);
    }

    if (params.asc) {
      queryParams.set("asc", params.asc);
    }

    const path = `/ap/category/${category.id}/followers`;

    let url = `${path}.json`;
    if (queryParams.size) {
      url += `?${queryParams.toString()}`;
    }

    return ajax(url)
      .then((response) => ({ category, ...response }))
      .catch(popupAjaxError);
  },
});

export default ActivityPubFollowers;
