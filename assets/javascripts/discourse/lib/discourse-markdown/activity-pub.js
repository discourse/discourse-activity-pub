export function setup(helper) {
  helper.allowList(["div.note"]);

  helper.registerOptions((opts) => {
    opts.features["activity-pub"] = true;
  });

  helper.registerPlugin((md) => {
    md.inline.bbcode.ruler.push("note", {
      tag: "note",
      wrap: "div.note",
    });

    md.block.bbcode.ruler.push("note", {
      tag: "note",
      wrap: "div.note",
    });
  });
}
