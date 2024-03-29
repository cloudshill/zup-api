module Flows::Steps::Triggers
  class API < Grape::API
    resources ':step_id/triggers' do
      desc 'Get all Triggers'
      get do
        authenticate!
        validate_permission!(:view, Trigger)
        { triggers: Trigger::Entity.represent(Step.find(safe_params[:step_id]).triggers) }
      end

      desc 'Order all Triggers'
      params { requires :ids, type: Array, desc: 'Ids of Triggers in order' }
      put do
        authenticate!
        validate_permission!(:update, Trigger)

        Step.find(safe_params[:step_id]).triggers.update_order!(safe_params[:ids])
        { message: I18n.t(:trigger_order_updated) }
      end

      desc 'Create a Trigger'
      params do
        requires :title,                         type: String, desc: 'Title of Trigger'
        requires :trigger_conditions_attributes, type: Array,  desc: 'Conditions of Trigger'
        requires :action_type,                   type: String, desc: 'Action type of Trigger'
        requires :action_values,                 type: Array,  desc: 'Action values of Trigger'
        optional :description,                   type: String, desc: 'Description of Trigger'
      end
      post do
        authenticate!
        validate_permission!(:create, Trigger)

        parameters = safe_params.permit(:title, :description, :action_type, action_values: [],
                                        trigger_conditions_attributes: [:field_id, :condition_type, values: []])
        trigger = Step.find(safe_params[:step_id]).triggers.create!(parameters.merge(user: current_user))
        { message: I18n.t(:trigger_created), trigger: Trigger::Entity.represent(trigger) }
      end

      desc 'Update a Trigger'
      params do
        requires :title,                         type: String, desc: 'Title of Trigger'
        requires :trigger_conditions_attributes, type: Array,  desc: 'Conditions of Trigger'
        requires :action_type,                   type: String, desc: 'Action type of Trigger'
        requires :action_values,                 type: Array,  desc: 'Action values of Trigger'
        optional :description,                   type: String, desc: 'Description of Trigger'
      end
      put ':id' do
        authenticate!
        validate_permission!(:update, Trigger)

        parameters = safe_params.permit(:title, :description, :action_type, action_values: [],
                                        trigger_conditions_attributes: [:id, :field_id, :condition_type, values: []])

        Step.find(safe_params[:step_id]).triggers.find(safe_params[:id]).update!(parameters.merge(user: current_user))
        { message: I18n.t(:trigger_updated) }
      end

      desc 'Delete a Trigger'
      delete ':id' do
        authenticate!
        validate_permission!(:delete, Trigger)

        trigger = Step.find(safe_params[:step_id]).triggers.find(safe_params[:id])
        trigger.user = current_user
        trigger.inactive!
        { message: I18n.t(:trigger_deleted) }
      end

      mount Flows::Steps::Triggers::TriggerConditions::API
    end
  end
end
