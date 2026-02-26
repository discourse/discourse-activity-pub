import Component from "@glimmer/component";
import { translateSize } from "discourse/lib/avatar-utils";

const PRIVATE_HOST_PATTERN =
  /^(localhost|127\.\d+\.\d+\.\d+|10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+|\[::1\])$/i;

export default class ActivityPubActorImage extends Component {
  get size() {
    return translateSize(this.args.size);
  }

  get url() {
    const iconUrl = this.args.actor?.icon_url;
    if (!iconUrl) {
      return "/images/avatar.png";
    }

    try {
      const parsed = new URL(iconUrl);
      if (PRIVATE_HOST_PATTERN.test(parsed.hostname)) {
        return "/images/avatar.png";
      }
    } catch {
      return "/images/avatar.png";
    }

    return iconUrl;
  }

  get title() {
    return this.args.actor?.handle;
  }

  <template>
    <img
      loading="lazy"
      alt=""
      width={{this.size}}
      height={{this.size}}
      src={{this.url}}
      title={{this.title}}
    />
  </template>
}
