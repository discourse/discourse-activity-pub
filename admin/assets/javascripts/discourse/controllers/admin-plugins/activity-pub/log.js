import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { notEmpty } from "@ember/object/computed";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ActivityPubLogJsonModal from "../../../components/modal/activity-pub-log-json";
import ActivityPubLog from "../../../models/activity-pub-log";

export default class AdminPluginsActivityPubLog extends Controller {
  @service modal;

  @tracked order = "";
  @tracked asc = null;
  @tracked loadingMore = false;
  loadMoreUrl = "";
  total = "";

  @notEmpty("logs") hasLogs;

  queryParams = ["order", "asc"];

  @action
  async loadMore() {
    if (!this.loadMoreUrl || this.total <= this.logs.length) {
      return;
    }

    this.loadingMore = true;

    try {
      const response = await ajax(this.loadMoreUrl);
      if (response) {
        this.logs.push(
          ...(response.logs || []).map((log) => {
            return ActivityPubLog.create(log);
          })
        );
        this.setProperties({
          loadMoreUrl: response.meta.load_more_url,
          total: response.meta.total,
          loadingMore: false,
        });
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  updateOrder(field, asc) {
    this.setProperties({
      order: field,
      asc,
    });
  }

  @action
  showJson(log) {
    this.modal.show(ActivityPubLogJsonModal, {
      model: {
        log,
      },
    });
  }
}
