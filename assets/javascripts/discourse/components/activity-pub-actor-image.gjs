import Component from "@glimmer/component";
import { buildHandle } from "../lib/activity-pub-utilities";
import { translateSize } from "discourse-common/lib/avatar-utils";

export default class ActivityPubActorImage extends Component {
    get size() {
        return translateSize(this.args.size);
    }

    get url() {
        return this.args.actor.icon_url || "/images/avatar.png";
    }

    get title() {
        return buildHandle({ actor: this.args.actor });
    }

    <template>
        <img
            loading='lazy'
            alt=''
            width={{this.size}}
            height={{this.size}}
            src={{this.url}}
            title={{this.title}} />
    </template>
}