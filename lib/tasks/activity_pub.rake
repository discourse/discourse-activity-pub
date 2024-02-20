# frozen_string_literal: true

desc "Print information about a stored ActivityPub object"
task "activity_pub:info", %i[ap_id] => :environment do |_, args|
  ap_id = args[:ap_id]

  if !ap_id || !DiscourseActivityPub::URI.parse(ap_id)
    puts "ERROR: Expecting activity_pub:import_outbox[ap_id]"
    exit 1
  end

  object = DiscourseActivityPub.info(ap_id)

  if !object
    puts "Could not find #{ap_id}"
    exit 1
  end

  columns = "%-5s | %-10s | %-10s | %-10s\n"
  line = "--------------------------------------------\n"
  puts "\n"
  puts "ActivityPub info for #{ap_id}"
  puts line
  printf columns,
         "id",
         "type",
         "ap_type",
         "local"
  puts line
  printf columns,
         object.id,
         object.type,
         object.ap_type,
         object.local
  puts line
  puts "\n"
end

desc "Imports activities from an actor's outbox"
task "activity_pub:import_outbox", %i[actor_id target_actor_id] => :environment do |_, args|
  actor_id = args[:actor_id]
  target_actor_id = args[:target_actor_id]

  if !actor_id || !target_actor_id
    puts "ERROR: Expecting activity_pub:import_outbox[actor_id,target_actor_id]"
    exit 1
  end

  DiscourseActivityPub::Logger.to_stdout = true
  DiscourseActivityPub::OutboxImporter.perform(actor_id: actor_id, target_actor_id: target_actor_id)
end