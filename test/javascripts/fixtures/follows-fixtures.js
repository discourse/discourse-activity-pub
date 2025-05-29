export default {
  "/ap/local/actor/1/follows": {
    actors: [
      {
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
      {
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
    ],
    meta: {
      total: 2,
      load_more_url: "/ap/local/actor/2/follows.json?page=1",
    },
  },
  "/ap/local/actor/2/follows": {
    actors: [
      {
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
      {
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
    ],
    meta: {
      total: 2,
      load_more_url: "/ap/local/actor/2/follows.json?page=1",
    },
  },
};
