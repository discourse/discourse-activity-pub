import { getOwner } from "discourse-common/lib/get-owner";

export default {
  setupComponent(attrs, component) {
    const controller = getOwner(this).lookup("controller:composer");
    component.set("category", controller.get("model.category"));
    controller.addObserver("model.category", () => {
      if (this._state === "destroying") {
        return;
      }
      component.set("category", controller.get("model.category"));
    });
  },
};
