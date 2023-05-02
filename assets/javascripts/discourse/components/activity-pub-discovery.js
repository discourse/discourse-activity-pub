import Component from "@glimmer/component";
import { action } from "@ember/object";
import { createPopper } from "@popperjs/core";
import { tracked } from "@glimmer/tracking";
import { bind } from "discourse-common/utils/decorators";
import { scheduleOnce } from "@ember/runloop";

export default class ActivityPubDiscovery extends Component {
  @tracked showDropdown = false;

  createDropdown() {
    document.addEventListener("click", this.handleOutsideClick);

    const dropdown = document.querySelector(".activity-pub-discovery-dropdown");
    if (!dropdown) {
      return;
    }
    const container = document.querySelector(".activity-pub-discovery");

    this._popper = createPopper(container, dropdown, {
      strategy: "absolute",
      placement: "bottom-start",
      modifiers: [
        {
          name: "preventOverflow",
        },
        {
          name: "offset",
          options: {
            offset: [0, 5],
          },
        },
      ],
    });
  }

  willDestroy() {
    this.onClose();
  }

  @bind
  handleOutsideClick(event) {
    const dropdown = document.querySelector(".activity-pub-discovery-dropdown");
    if (dropdown && !dropdown.contains(event.target)) {
      this.onClose(event);
    }
  }

  @action
  onClose(event) {
    this.showDropdown = false;
    event?.stopPropagation();
    document.removeEventListener("click", this.handleOutsideClick);
    this._popper = null;
  }

  @action
  toggleDropdown() {
    this.showDropdown = !this.showDropdown;

    if (this.showDropdown) {
      scheduleOnce("afterRender", this, this.createDropdown);
    }
  }
}
