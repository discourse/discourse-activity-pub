export function buildHandle({ actor, model, site }) {
  if ((!actor && !model) || (model && !site)) {
    return undefined;
  } else {
    const username = actor ? actor.username : model.activity_pub_username;
    const domain = actor ? actor.domain : site.activity_pub_host;
    return `${username}@${domain}`;
  }
}
