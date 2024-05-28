# frozen_string_literal: true

def print_info(info)
  return unless info

  columns = "%-10s | %-10s | %-15s | %-20s | %-10s | %-10s | %-10s | %-10s | %-10s\n"
  line =
    "-------------------------------------------------------------------------------------------------------------------------------------\n"
  puts "\n"
  puts "ActivityPub Info"
  puts line
  printf columns,
         "stored",
         "id",
         "type",
         "subtype",
         "local",
         "object",
         "object id",
         "model",
         "model id"
  info.each do |object|
    puts line
    printf columns,
           object[:stored],
           object[:id],
           object[:type],
           object[:ap_type],
           object[:local],
           object[:object_type],
           object[:object_id],
           object[:model_type],
           object[:model_id]
  end
  puts line
  puts "\n"
end

def setup_logger(args)
  log_type = :info

  if args[:log_type]
    DiscourseActivityPub::Logger.log_types.include?(args[:log_type].to_sym)
    log_type = args[:log_type].to_sym
  end

  DiscourseActivityPub::Logger.to_stdout = log_type
end

def format_stored_info(info)
  return [] if info.blank?

  info.map do |object|
    object = object.to_h
    object[:stored] = true
    object
  end
end

desc "Print information about a stored ActivityPub object"
task "activity_pub:info", %i[ap_id] => :environment do |_, args|
  ap_id = args[:ap_id]

  if !ap_id
    puts "ERROR: Expecting activity_pub:info[ap_id]"
    exit 1
  end

  info = DiscourseActivityPub.info([ap_id])

  if info.present?
    info = format_stored_info(info)
  else
    resolved_object = DiscourseActivityPub::AP::Object.resolve(ap_id)

    if resolved_object.present?
      object = {
        stored: false,
        id: nil,
        type: resolved_object.base_type,
        ap_type: resolved_object.type,
        local: false,
        object_type: resolved_object.json.dig(:object, :type),
        object_id: nil,
        model_type: nil,
        model_id: nil,
      }
      info = [object]
    end
  end

  if !info.present?
    puts "Could not find #{ap_id}"
    exit 1
  end

  print_info(info)
end

desc "Process activities of a remote actor"
task "activity_pub:process",
     %i[actor_id_or_handle target_actor_id_or_handle log_type] => :environment do |_, args|
  actor_id_or_handle = args[:actor_id_or_handle]
  target_actor_id_or_handle = args[:target_actor_id_or_handle]
  log_type = args[:log_type]

  if !actor_id_or_handle || !target_actor_id_or_handle
    puts "ERROR: Expecting activity_pub:process[actor_id_or_handle,target_actor_id_or_handle,log_type]"
    exit 1
  end

  actor = DiscourseActivityPubActor.find_by_id_or_handle(actor_id_or_handle)

  if !actor
    puts "Could not find actor"
    exit 1
  end

  target_actor =
    DiscourseActivityPubActor.find_by_id_or_handle(target_actor_id_or_handle, local: false)

  if !target_actor
    puts "Could not find target actor"
    exit 1
  end

  setup_logger(args)

  DiscourseActivityPub::Bulk::Process.perform(actor_id: actor.id, target_actor_id: target_actor.id)
end

desc "Publishes unpublished activities of an actor"
task "activity_pub:publish", %i[actor_id_or_handle log_type] => :environment do |_, args|
  actor_id_or_handle = args[:actor_id_or_handle]
  log_type = args[:log_type]

  if !actor_id_or_handle
    puts "ERROR: Expecting activity_pub:publish[actor_id_or_handle,log_type]"
    exit 1
  end

  actor = DiscourseActivityPubActor.find_by_id_or_handle(actor_id_or_handle)

  if !actor
    puts "Could not find actor"
    exit 1
  end

  setup_logger(args)

  DiscourseActivityPub::Bulk::Publish.perform(actor_id: actor.id)
end
