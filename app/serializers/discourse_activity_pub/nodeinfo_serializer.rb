# frozen_string_literal: true

module DiscourseActivityPub
  class NodeinfoSerializer < ActiveModel::Serializer
    attributes :version, :software, :protocols, :services, :usage, :openRegistrations, :metadata

    def software
      format(object.software).as_json
    end

    def services
      format(object.services).as_json
    end

    def usage
      format(object.usage).as_json
    end

    def openRegistrations
      object.open_registrations
    end

    def metadata
      format(object.metadata).as_json
    end

    protected

    def format(hash)
      hash.deep_transform_keys do |key|
        case key
        when :active_half_year
          "activeHalfyear"
        else
          key.to_s.camelize(:lower)
        end
      end
    end
  end
end
