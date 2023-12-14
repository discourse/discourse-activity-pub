import Component from "@glimmer/component";

export default class ActivityPubActorHandleLink extends Component {
    <template>
        <a href={{this.args.actor.url}} target="_blank" rel="noopener noreferrer">
            {{this.args.actor.handle}}
        </a>
    </template>
}
