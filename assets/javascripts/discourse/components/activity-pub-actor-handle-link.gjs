const ActivityPubActorHandleLink = <template>
  <a href={{@actor.url}} target="_blank" rel="noopener noreferrer">
    {{@actor.handle}}
  </a>
</template>;

export default ActivityPubActorHandleLink;
