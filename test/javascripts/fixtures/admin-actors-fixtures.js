export default {
  "/admin/plugins/ap/actor?model_type=category": {
    actors: [
      {
        id: 1,
        handle: "@angus_ap@test.local",
        name: "Cat 1",
        username: "cat_1",
        local: true,
        domain: "test.local",
        url: "https://test.local/c/cat-1",
        default_visibility: "public",
        post_object_type: "Note",
        publication_type: "first_post",
        model_type: "Category",
        model_id: 1,
        model: {
          id: 1,
          name: "Cat 1",
          slug: "cat-1",
        },
      },
      {
        id: 2,
        handle: "@angus_ap@test.local",
        name: "Cat 2",
        username: "cat_2",
        local: true,
        domain: "test.local",
        url: "https://test.local/c/cat-2",
        default_visibility: "public",
        post_object_type: "Note",
        publication_type: "first_post",
        model_type: "Category",
        model_id: 2,
        model: {
          id: 2,
          name: "Cat 2",
          slug: "cat-2",
        },
      },
    ],
    meta: {
      total: 2,
      load_more_url:
        "/admin/plugins/ap/actor.json?model_type=category&offset=4",
    },
  },
  "/admin/plugins/ap/actor?model_type=tag": {
    actors: [
      {
        id: 4,
        handle: "@monkey@test.local",
        name: "Monkey",
        username: "monkey",
        local: true,
        default_visibility: "public",
        publication_type: "first_post",
        post_object_type: "Note",
        model_type: "Tag",
        model_id: 1,
        model: {
          id: 1,
          name: "Monkey",
          slug: "monkey",
        },
      },
    ],
    meta: {
      total: 2,
      load_more_url: "/admin/plugins/ap/actor.json?model_type=tag&offset=1",
    },
  },
};
