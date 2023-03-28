export function setup(helper) {
  helper.allowList(["div.note"]);

  helper.registerOptions((opts) => {
    opts.features["activity-pub"] = true;
  });

  helper.registerPlugin((md) => {
    const ruler = md.inline.bbcode.ruler;

    ruler.push("note", {
      tag: "note",
      wrap: "div.note",
    });
  });
}
