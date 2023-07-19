const customFieldDefaults = {
  activity_pub_default_visibility: "public",
  activity_pub_post_object_type: "note",
  activity_pub_publication_type: "first_post"
};

export default {
  setupComponent(attrs) {
    Object.keys(customFieldDefaults).forEach((key) => {
      if (attrs.category.custom_fields[key] === undefined) {
        attrs.category.custom_fields[key] = customFieldDefaults[key];
      }
    });
  },
};
