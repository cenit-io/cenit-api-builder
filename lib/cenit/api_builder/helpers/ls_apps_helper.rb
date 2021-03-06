module Cenit
  module ApiBuilder
    module Helpers
      module LSAppHelper
        def parse_from_record_to_response_ls_app(record, with_details = false)
          response = {
            id: record.id.to_s,
            namespace: record.namespace,
            listening_path: record.listening_path,
          }

          if with_details != :ref
            response.merge!(
              access_token: record.access_token,

              specification: record.specification.try do |spec|
                {
                  id: spec.id.to_s,
                  title: spec.title,
                }
              end,

              services: record.services.map { |service| parse_from_record_to_response_ls_ref(service) },
              updated_at: parse_datetime(record.updated_at),
              created_at: parse_datetime(record.created_at),
            )
          end

          response
        end

        def parse_from_record_to_response_ls_ref(service)
          {
            id: service.id.to_s,
            listen: parse_from_record_to_response_ls_listen(service, false),
            active: service.active
          }
        end

        def parse_from_params_to_selection_ls_apps_criteria
          exp_term = { '$regex' => ".*#{params[:term]}.*", '$options' => 'i' }
          terms_conditions = [{ namespace: exp_term }, { 'listening_path': exp_term }]
          { '$and' => [{ '$or' => terms_conditions }] }
        end

        def ls_app_params(action)
          parameters = params.permit(
            data: [
              :namespace, :listening_path,
              :specification => [:id]
            ]
          ).to_h

          check_attr_validity(:data, nil, parameters, true, Hash)

          data = parameters[:data]

          if action == :update
            check_allow_params(%i[listening_path], data)
            data[:id] = params[:id]
          else
            check_allow_params(%i[listening_path namespace specification], data)
            check_attr_validity(:namespace, nil, data, true, String)
            check_attr_validity(:specification, nil, data, true, Hash)
            check_attr_validity(:id, 'specification', data[:specification], true, String)
            data[:specification][:_reference] = true
          end

          check_attr_validity(:listening_path, nil, data, true, String)

          data
        end
      end
    end
  end
end
