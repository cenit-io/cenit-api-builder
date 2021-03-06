require 'cenit/api_builder/models/open_api_spec'
require 'cenit/api_builder/models/bridging_service_application'
require 'cenit/api_builder/models/local_service_application'

module Cenit
  module ApiBuilder
    module Helpers
      module AdminHelper
        private

        def find_data_type
          @dt = begin
            case params[:model].to_sym
            when :open_api_spec, :api_spec
              Cenit::ApiBuilder::OpenApiSpec
            when :bs_apps
              Cenit::ApiBuilder::BridgingServiceApplication
            when :ls_apps
              Cenit::ApiBuilder::LocalServiceApplication
            when :bridging_services
              Cenit::ApiBuilder::BridgingService
            when :local_services
              Cenit::ApiBuilder::LocalService
            when :tenants
              Tenant.data_type
            when :webhooks, :connections, :json_data_types, :authorizations
              Cenit.namespace(:Setup).data_type(params[:model].singularize.classify)
            end
          end

          respond_with_exception('[400] - Invalid model') unless @dt
        end

        def find_record
          @record = @dt.where(id: params[:id]).first
          respond_with_exception('[404] - Not found') unless @record
        end

        def find_access_token
          @access_token ||= begin
            token_type, token = request.headers['Authorization'].to_s.split(' ')
            token ||= params[:token]
            token_type ||= 'Bearer'

            Cenit::OauthAccessToken.where(token_type: token_type.to_s, token: token.to_s).first
          end

          @access_token
        end

        def find_authorize_account_by_id
          if tenant = Tenant.where(id: params[:tenant_id]).first
            User.current = tenant.owner
            Cenit::MultiTenancy.tenant_model.current = tenant
          end

          render json: { error: 'Unauthorized' }, status: 403 if tenant.nil?
        end

        def find_authorize_account_by_token
          if access_token = find_access_token
            User.current = access_token.user
            access_token.set_current_tenant!
          end

          render json: { error: 'Unauthorized' }, status: 403 unless access_token.try(:user)
        end

        def check_parameters
          raise('Invalid model') unless @dt
        end

        def respond_with_exception(ex)
          msg = begin
            case ex
            when String
              ex
            when Mongoid::Errors::MongoidError
              ex.summary
            when StandardError
              ex.message
            else
              ex.to_s
            end
          end

          code = msg =~ /^\[(\d+)\]/ ? $1.to_i : 500
          data = { type: 'exception', error: msg.gsub(/^\[(\d+)\] - /, ''), code: code }

          Tenant.notify(message: msg, type: :error)

          render json: data, status: code
        end

        def respond_with_record(record, type = nil)
          type ||= record.class.data_type.name.underscore

          response = begin
            {
              type: record.class.data_type.name.underscore,
              data: begin
                if respond_to?(parse_method = "parse_from_record_to_response_#{type.singularize}")
                  send(parse_method, record, true)
                else
                  record.to_hash(include_id: true).deep_symbolize_keys
                end
              end
            }
          end

          respond_with_format(response)
        end

        def parse_sort_params
          parameters = params.permit(sort: {})
          sort ||= parameters[:sort] || { created_at: 'DESC' }
          sort = { sort => 'DESC' } if sort.is_a?(String)
          sort.to_h.deep_symbolize_keys
        end

        def respond_with_records(dt, type = nil)
          type ||= dt.name.underscore

          parse_method = "parse_from_params_to_selection_#{type}_criteria"
          criteria = respond_to?(parse_method) ? send(parse_method) : {}
          offset = params[:offset].to_i
          limit = (params[:limit] || 10).to_i
          sort = parse_sort_params
          total = dt.where(criteria).count

          response = begin
            if params[:without_data].to_b
              { type: dt.name.underscore, data: [], pagination: { offset: 0, limit: limit, total: total } }
            else
              {
                type: dt.name.underscore,
                data: begin
                  dt.where(criteria).order_by(sort).skip(offset).limit(limit).to_a.map do |record|
                    if respond_to?(parse_method = "parse_from_record_to_response_#{type.singularize}")
                      send(parse_method, record, false)
                    else
                      record.to_hash(include_id: true).deep_symbolize_keys
                    end
                  end
                end,
                pagination: { offset: offset, limit: limit, total: total }
              }
            end
          end

          respond_with_format(response)
        end

        def respond_with_format(response, format = nil, status = 200)
          format ||= params[:format]

          if format == 'yaml'
            render text: response.to_yaml, content_type: 'text/yaml'
          else
            render json: response, code: status
          end
        end

        def parse_request_data(model, action)
          method = "#{model.singularize}_params"
          respond_to?(method) ? send(method, action) : params.permit(data: {}).to_h[:data]
        end

        def fill_from_data(record, data)
          if respond_to?(fill_method = "fill_#{params[:model].singularize}_from_data")
            send(fill_method, record, data)
          else
            record.from_json(data, { reset: true })
          end
        end

        def parse_datetime(value)
          return if value.nil?

          value = value.iso8601 if value.is_a?(Time)
          value = DateTime.parse(value) if value.is_a?(String)
          value.iso8601
        end

        def check_allow_params(allow_keys, data = nil)
          data ||= params
          if attr = data.keys.detect { |k| !allow_keys.include?(k.to_s) && !allow_keys.include?(k.to_sym) }
            Cenit.fail("[400] - Unexpected '#{attr}' parameter")
          end
        end

        def check_attr_validity(attr, scope_name, scope, required = true, klass = nil, format = nil)
          unless required.in?([true, false])
            format = klass
            klass = required
            required = true
          end

          if klass.is_a?(Regexp) || klass.is_a?(Symbol) || klass.is_a?(Array)
            format = klass
            klass = nil
          end

          scope[attr] = scope[attr].strip if scope[attr].is_a?(String)

          check_attr_required(attr, scope_name, scope, required)
          check_attr_class(attr, scope_name, scope, klass)
          check_attr_format(attr, scope_name, scope, format)
        end

        def check_attr_required(attr, scope_name, scope, required = true)
          return unless required

          scope = scope.to_h if scope.is_a?(ActionController::Parameters)
          full_name = scope_name ? "#{scope_name}[#{attr}]" : attr
          raise("[400] - The parameter #{full_name} is required") if scope[attr].blank? && scope[attr] != false
        end

        def check_attr_class(attr, scope_name, scope, klass = nil)
          return if scope[attr].nil? || klass.nil?

          full_name = scope_name ? "#{scope_name}[#{attr}]" : attr
          raise("[400] - The parameter #{full_name} must be #{klass.name}") unless scope[attr].is_a?(klass)
        end

        def check_attr_format(attr, scope_name, scope, format = nil)
          return if scope[attr].nil? || format.nil?

          begin
            case format
            when Regexp
              raise('is not valid') if format !~ scope[attr].to_s
            when :date
              raise('is not a valid date (YYYY-MM-DD)') if scope[attr].to_s !~ /^\d{4}\-\d{2}\-\d{2}$/

              begin
                DateTime.parse(scope[attr])
              rescue StandardError
                raise('is not a valid date (YYYY-MM-DD)')
              end

            when :iso8601
              exp = /^\d{4}\-\d{2}\-\d{2}(T\d{2}:\d{2}:\d{2}(\.\d{1,3})?(([ +-]\d{2}:\d{2})|Z)?)?$/
              raise('is not a valid date (iso8601: YYYY-MM-DDTHH:MM:SSZ)') if scope[attr].to_s !~ exp

              scope[attr].gsub!(/ (\d{2}:\d{2})$/, '+\1')
              begin
                DateTime.parse(scope[attr])
              rescue StandardError
                raise('is not a valid date (iso8601: YYYY-MM-DDTHH:MM:SSZ)')
              end
            when Array
              raise('is not valid') unless format.include?(scope[attr])
            else
              send("check_attr_format_#{format}", attr, scope)
            end
          rescue StandardError => ex
            full_name = scope_name ? "#{scope_name}[#{attr}]" : attr
            raise("[400] - The parameter #{full_name} #{ex.message}")
          end
        end

        def check_service_request(s_listening_path, s_req_path)
          s_listening_path.gsub!(/^\//, '')
          s_req_path.gsub!(/^\//, '')
          path_params_names = []
          path_tokens = s_listening_path.split('/')

          path_tokens.each_with_index do |path_token, idx|
            if path_token =~ /^:(\w+)/
              path_params_names << $1.to_sym
              path_tokens[idx] = '([^/]+)'
            end
          end

          parameters = params.permit(qs: {})
          path_pattern = /^#{path_tokens.join('/')}$/

          request.body.rewind
          @payload = JSON.parse(request.body.read) rescue @payload
          @path_params = {}.with_indifferent_access
          @query_params = parameters[:qs] || {}.with_indifferent_access
          return nil unless match = path_pattern.match(s_req_path)

          path_params_names.each_with_index do |name, idx|
            @path_params[name] = URI.decode(match[idx + 1].force_encoding('UTF-8'))
          end

          true
        end
      end
    end
  end
end
