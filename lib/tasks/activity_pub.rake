# frozen_string_literal: true

def print_info(info)
  return unless info

  columns = "%-5s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s | %-10s\n"
  line = "------------------------------------------------------------------------------------------------\n"
  puts "\n"
  puts "ActivityPub Info"
  puts line
  printf columns,
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
          object.id,
          object.type,
          object.ap_type,
          object.local,
          object.object_type,
          object.object_id,
          object.model_type,
          object.model_id
  end
  puts line
  puts "\n"
end

desc "Print information about a stored ActivityPub object"
task "activity_pub:info", %i[ap_ids] => :environment do |_, args|
  ap_ids = args[:ap_ids]

  if !ap_ids
    puts "ERROR: Expecting activity_pub:info[ap_id|ap_id]"
    exit 1
  end

  info = DiscourseActivityPub.info(ap_ids.split("|"))

  if !info
    puts "Could not find #{ap_ids}"
    exit 1
  end

  print_info(info)
end

desc "Imports activities from an actor's outbox"
task "activity_pub:import_outbox", %i[actor_id_or_handle target_actor_id_or_handle log_type] => :environment do |_, args|
  actor_id_or_handle = args[:actor_id_or_handle]
  target_actor_id_or_handle = args[:target_actor_id_or_handle]
  log_type = args[:log_type]

  if !actor_id_or_handle || !target_actor_id_or_handle
    puts "ERROR: Expecting activity_pub:import_outbox[actor_id_or_handle,target_actor_id_or_handle,log_type]"
    exit 1
  end

  actor = DiscourseActivityPubActor.find_by_id_or_handle(actor_id_or_handle)

  if !actor
    puts "Could not find actor"
    exit 1
  end

  target_actor = DiscourseActivityPubActor.find_by_id_or_handle(target_actor_id_or_handle, local: false)

  if !target_actor
    puts "Could not find target actor"
    exit 1
  end

  log_type = :info

  if args[:log_type]
    DiscourseActivityPub::Logger.log_types.include?(args[:log_type].to_sym)
    log_type = args[:log_type].to_sym
  end

  DiscourseActivityPub::Logger.to_stdout = log_type
  result = DiscourseActivityPub::OutboxImporter.perform(actor_id: actor.id, target_actor_id: target_actor.id)

  if result[:success].present?
    info = DiscourseActivityPub.info(result[:success])
    print_info(info)
  end
end