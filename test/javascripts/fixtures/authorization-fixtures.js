export default {
  "/ap/auth.json": {
    authorizations: [
      {
        id: 1,
        user_id: 1,
        auth_type: "mastodon",
        actor: {
          handle: "@angus_ap@test.local",
          name: "Angus",
          username: "angus_ap",
          local: true,
          domain: "test.local",
          url: "https://test.local/u/angus_ap",
          followed_at: "2013-02-08T12:00:00.000Z",
          icon_url: "/images/avatar.png",
          model: {
            username: "angus_local",
          },
        },
      },
      {
        id: 2,
        user_id: 2,
        auth_type: "discourse",
        actor: {
          handle: "@angus_ap@test.local",
          name: "Bob",
          username: "bob_ap",
          local: false,
          domain: "test.remote",
          url: "https://test.remote/u/bob_ap",
          followed_at: "2014-02-08T12:00:00.000Z",
          icon_url: "/images/avatar.png",
          model: {
            username: "bob_local",
          },
        },
      },
    ],
  },
};
