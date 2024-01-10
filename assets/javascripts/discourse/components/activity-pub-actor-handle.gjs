import Component from "@glimmer/component";
import { buildHandle } from "../lib/activity-pub-utilities";

export default class ActivityPubActorHandle extends Component {
  get handle() {
    return buildHandle({ actor: this.args.actor });
  }

  <template>
    <a href={{@actor.url}} target="_blank" rel="noopener noreferrer">
      {{this.handle}}
    </a>
  </template>
}
