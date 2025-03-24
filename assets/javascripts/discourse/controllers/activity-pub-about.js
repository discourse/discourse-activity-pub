import Controller from "@ember/controller";
import { notEmpty } from "@ember/object/computed";

export default class ActivityPubAbout extends Controller {
  @notEmpty("tagActors") hasTagActors;
  @notEmpty("categoryActors") hasCategoryActors;
}
