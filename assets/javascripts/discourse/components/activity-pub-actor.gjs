
import Component from "@glimmer/component";
import ActivityPubActorImage from "./activity-pub-actor-image";
import ActivityPubActorHandleLink from "./activity-pub-actor-handle-link";
import or from "truth-helpers/helpers/or";

export default class ActivityPubActor extends Component {
    <template>
        <div class="activity-pub-actor">
            <div class="activity-pub-actor-image">
                <ActivityPubActorImage @actor={{@actor}} @size="large" />
            </div>
            <div class="activity-pub-actor-content">
                <div class="activity-pub-actor-name">
                    {{or @actor.name @actor.username}}
                </div>
                <div class="activity-pub-actor-handle">
                    <ActivityPubActorHandleLink @actor={{@actor}} />
                </div>
            </div>
        </div>
    </template>
}