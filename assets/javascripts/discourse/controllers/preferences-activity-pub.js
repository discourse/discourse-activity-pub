import Controller from "@ember/controller";
import { notEmpty, readOnly } from "@ember/object/computed";

export default class PreferencesActivityPubController extends Controller {
  @notEmpty("authorizations") hasAuthorizations;
  @readOnly("model.activity_pub_authorizations") authorizations;
}
