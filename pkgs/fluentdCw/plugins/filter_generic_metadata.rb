require "socket"

require "fluent/filter"

module Cloudwatt
  class GenericMetadataFilter < ::Fluent::Filter

    ::Fluent::Plugin.register_filter("generic_metadata", self)

    KUBERNETES_NAMESPACE_FILE = "/run/secrets/kubernetes.io/serviceaccount/namespace"

    def configure(conf)
      super
      cache_docker_metadata
      cache_kubernetes_metadata
      cache_service_metadata
    end

    def filter_stream(tag, es)
      new_es = Fluent::MultiEventStream.new
      es.each do |time, record|
        add_docker_metadata record
        add_kubernetes_metadata record
        add_service_metadata record
        cleanup_fluentd_record(record) if tag.start_with? "fluent"
        new_es.add time, record
      end
      new_es
    rescue => e
      log.warn "failed to parse record", error_class: e.class, error: e.message
      log.warn_backtrace
    end

    private

    def add_docker_metadata(record)
      return unless @container_id
      record["docker"] ||= {}
      record["docker"]["container_id"] = @container_id
    end

    def add_kubernetes_metadata(record)
      return unless @kubernetes_namespace
      record["kubernetes"] ||= {}
      record["kubernetes"]["namespace"] ||= @kubernetes_namespace
      record["kubernetes"]["pod_name"] ||= @kubernetes_pod_name
    end

    def add_service_metadata(record)
      record["application"] ||= @application if @application
      record["service"] ||= @service if @service
    end

    def cache_docker_metadata
      @container_id = File.read("/proc/1/cpuset").strip[/[^\/]+$/] rescue nil
    end

    def cache_kubernetes_metadata
      @kubernetes_namespace = ENV["KUBERNETES_NAMESPACE"] || (File.read(KUBERNETES_NAMESPACE_FILE) rescue nil)
      return unless @kubernetes_namespace
      @kubernetes_pod_name = ENV["KUBERNETES_POD_NAME"] || Socket.gethostname
    end

    def cache_service_metadata
      @application = ENV["application"]
      @service = ENV["service"]
    end

    def cleanup_fluentd_record(record)
      record["process_name"] ||= "fluentd"
      record["process_id"] ||= Process.pid
      record.delete "attrs"
      record.delete "log"
    end

  end
end
