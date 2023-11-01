export default {
  "/api/v2/instance": {
    domain: "mastodon.social",
    title: "Mastodon",
    version: "4.2.1",
    source_url: "https://github.com/mastodon/mastodon",
    description:
      "The original server operated by the Mastodon gGmbH non-profit",
    usage: {
      users: {
        active_month: 277875,
      },
    },
    thumbnail: {
      url:
        "https://files.mastodon.social/site_uploads/files/000/000/001/@1x/57c12f441d083cde.png",
      blurhash: "UeKUpFxuo~R%0nW;WCnhF6RjaJt757oJodS$",
      versions: {
        "@1x":
          "https://files.mastodon.social/site_uploads/files/000/000/001/@1x/57c12f441d083cde.png",
        "@2x":
          "https://files.mastodon.social/site_uploads/files/000/000/001/@2x/57c12f441d083cde.png",
      },
    },
    languages: ["en"],
    configuration: {
      urls: {
        streaming: "wss://streaming.mastodon.social",
        status: "https://status.mastodon.social",
      },
      accounts: {
        max_featured_tags: 10,
      },
      statuses: {
        max_characters: 500,
        max_media_attachments: 4,
        characters_reserved_per_url: 23,
      },
      media_attachments: {
        supported_mime_types: [
          "image/jpeg",
          "image/png",
          "image/gif",
          "image/heic",
          "image/heif",
          "image/webp",
          "image/avif",
          "video/webm",
          "video/mp4",
          "video/quicktime",
          "video/ogg",
          "audio/wave",
          "audio/wav",
          "audio/x-wav",
          "audio/x-pn-wave",
          "audio/vnd.wave",
          "audio/ogg",
          "audio/vorbis",
          "audio/mpeg",
          "audio/mp3",
          "audio/webm",
          "audio/flac",
          "audio/aac",
          "audio/m4a",
          "audio/x-m4a",
          "audio/mp4",
          "audio/3gpp",
          "video/x-ms-asf",
        ],
        image_size_limit: 16777216,
        image_matrix_limit: 33177600,
        video_size_limit: 103809024,
        video_frame_rate_limit: 120,
        video_matrix_limit: 8294400,
      },
      polls: {
        max_options: 4,
        max_characters_per_option: 50,
        min_expiration: 300,
        max_expiration: 2629746,
      },
      translation: {
        enabled: true,
      },
    },
    registrations: {
      enabled: true,
      approval_required: false,
      message: null,
      url: null,
    },
  },
};
