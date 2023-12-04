import Controller from "@ember/controller";
import { inject as service } from "@ember/service";

export default class ActivityPubCategory extends Controller {
  @service composer;
  @service site;
}
