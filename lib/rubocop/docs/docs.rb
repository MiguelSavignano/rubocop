# frozen_string_literal: true

require 'rubocop'
require 'yaml'
require 'yard'

module RuboCop
  module Docs
    class CopDoc
      attr_accessor :cop, :yard_object, :name, :example, :description, :department_name, :config
      def initialize(cop, config)
        @cop = cop
        @config = config.for_cop(cop)
      end

      def name
        @name ||= @cop.cop_name
      end

      def department_name
        @department_name ||= @cop.department.to_s
      end

      def configuration
        display_keys = %w[Description Enabled StyleGuide Reference]
        config.select { |k| display_keys.include? k }
      end

      def configurable_attributes
        non_display_keys = %w[Description Enabled StyleGuide Reference]
        result = config.reject { |k| non_display_keys.include? k }
        result.map { |key, value| [key, value.is_a?(Array) ? value : value.to_s ] }.to_h
      end

      def yard_object
        return @yard_object if @yard_object
        result = nil

        YARD::Registry.all(:class).detect do |code_object|
          next unless RuboCop::Cop::Badge.for(code_object.to_s) == cop.badge
          result = code_object
        end
        @yard_object = result
      end

      def description
        return '' unless yard_object
        yard_object.docstring.to_s
      end

      def examples_description
        return '' unless yard_object
        return '' if yard_object.tags('example').empty?
        result = "```ruby\n"
        yard_object.tags('example').map do |x|
          result << x.text
        end
        result << "\n```\n"
        result
      end

      def as_json
        {
          name: name,
          department_name: department_name,
          description: description,
          examples_description: examples_description,
          configuration: configuration,
          configurable_attributes: configurable_attributes,
        }
      end
    end

    def self.main
      YARD::Rake::YardocTask.new do |task|
        task.files = ['lib/rubocop/cop/*/*.rb']
        task.options = ['--no-output']
      end
      YARD::Registry.load!

      cops   = RuboCop::Cop::Cop.registry
      config = RuboCop::ConfigLoader.default_configuration
      config['Rails']['Enabled'] = true
      result = []
      cops.each do |cop|
        result << RuboCop::Docs::CopDoc.new(cop, config)
      end
      result = result.map(&:as_json)

      File.write('rubocop-doc.yml', result.to_yaml)
    end
  end
end
