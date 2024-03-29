require 'spec_helper'

def add_can_execute_step(user, step)
  group = user.groups.first
  can_execute_step = group.can_execute_step || []
  group.update(permissions: group.permissions.merge(can_execute_step: can_execute_step.push(step)))
end

describe Cases::API, versioning: true do
  let(:user)       { create(:user) }
  let(:guest_user) { create(:guest_user) }

  describe 'on create' do
    context 'default test' do
      let(:flow) do
        flow = create(:flow, initial: true, steps: [build(:step_type_form_without_fields)])
        flow.steps.first.fields.create title: 'user_age',        field_type: 'integer', requirements: {presence: true, minimum: 1, maximum: 150}
        flow.steps.first.fields.create title: 'user_cpf',        field_type: 'cpf'
        flow.steps.first.fields.create title: 'user_email',      field_type: 'email'
        flow.steps.first.fields.create title: 'user_photo',      field_type: 'image'
        flow.steps.first.fields.create title: 'user_att',        field_type: 'attachment', filter: 'jpg,png,txt'
        flow.steps.first.fields.create title: 'inventory_items', field_type: 'category_inventory', category_inventory_id: inventory_item.category.id, multiple: true
        flow.steps.first.fields.create title: 'size_of_tree',    field_type: 'category_inventory_field', origin_field_id: inventory_field_id
        flow.steps.first.fields.create title: 'Services',        field_type: 'checkbox', values: {option_1: 'Option 1', option_2: 'Option 2'}
        flow.steps.first.fields.create title: 'Newsletter',      field_type: 'radio', values: {yes: 'Yes', no: 'No'}, requirements: {presence: true}
        flow.steps.first.fields.create title: 'Country',         field_type: 'select', values: {brazil: 'Brazil', usa: 'USA'}
        flow.reload
      end
      let(:inventory_field_id) { inventory_item.category.fields.first.id }
      let(:inventory_item)     { create(:inventory_item) }
      let(:fields)             { flow.steps.first.fields.all }
      let(:invalid_params) do
        {step_id: flow.steps.first.id,
          initial_flow_id: flow.id,
          version: flow.last_version,
          fields: [
            {id: fields.first.id,  value: 'invalid'},
            {id: fields.second.id, value: ''},
            {id: fields.third.id,  value: 'invalid'}
        ]}
      end
      let(:inventory_value) { '123' }
      let(:valid_params) do
        {step_id: flow.steps.first.id,
          initial_flow_id: flow.id,
          version: flow.last_version,
          fields: [
            {id: fields[0].id,  value: '18'},
            {id: fields[1].id, value: '146.832.574-40'},
            {id: fields[2].id,  value: 'chapolim@chaves.com'},
            {id: fields[3].id, value: [
              {file_name: 'valid_report_item_photo.jpg',
               content: Base64.encode64(fixture_file_upload('images/valid_report_item_photo.jpg').read)},
              {file_name: 'valid_report_item_photo2.jpg',
               content: Base64.encode64(fixture_file_upload('images/valid_report_item_photo.jpg').read)}
            ]},
            {id: fields[4].id, value: [
              {
                file_name: 'valid_report_item_attachement.jpg',
                content: Base64.encode64(fixture_file_upload('images/valid_report_item_photo.jpg').read)
              }
            ]},
            {id: fields[5].id, value: [inventory_item.id]},
            {id: fields[6].id, value: inventory_value},
            {id: fields[7].id, value: ['option_2']},
            {id: fields[8].id, value: 'no'},
            {id: fields[9].id, value: 'usa'}
        ]}
      end

      before { user.groups.first.update(permissions: user.groups.first.permissions.merge(can_execute_step: [valid_params[:step_id]])) }

      context  'no authentication' do
        before { post '/cases', valid_params }
        it     { expect(response.status).to be_an_unauthorized }
      end

      context 'with authentication' do
        context 'and user can\'t execute first Step on Flow' do
          let(:error) { I18n.t(:permission_denied, action: I18n.t(:create), table_name: I18n.t(:case_steps)) }

          before { post '/cases', valid_params, auth(guest_user) }
          it     { expect(response.status).to be_a_forbidden }
          it     { expect(parsed_body).to be_an_error(error) }
        end

        context 'and user can execute first Step on Flow' do
          context 'and failure' do
            context 'because validations fields' do
              let(:errors) do
                {"case_steps.fields" => [
                  "user_age #{I18n.t('errors.messages.greater_than', count: 1)}",
                  "user_email #{I18n.t('errors.messages.invalid')}",
                  "Newsletter #{I18n.t('errors.messages.blank')}"
                ]}
              end

              before { post '/cases', invalid_params, auth(user) }
              it     { expect(response.status).to be_a_bad_request }
              it     { expect(parsed_body).to be_an_error(errors) }
            end
          end

          context 'successfully' do
            let(:kase)       { Case.last }
            let(:inventory)  { inventory_item.data.find_by(inventory_field_id: inventory_field_id) }
            before { post '/cases', valid_params, auth(user) }
            it     { expect(response.status).to be_a_requisition_created }
            it     { expect(parsed_body).to be_a_success_message_with(I18n.t(:case_created)) }
            it     { expect(parsed_body['case']).to be_an_entity_of(kase, display_type: 'full') }

            it 'should has log entries' do
              expect(kase.cases_log_entries.count).to eql 1
            end

            it 'should update field on Inventory' do
              expect(inventory.reload.content.to_f).to eql inventory_value.to_f
            end
          end
        end
      end
    end

    context 'when step type is flow' do
      let(:flow) do
        flow = create(:flow, initial: true, steps: [build(:step, child_flow: build(:flow, steps: [build(:step_type_form_without_fields)]))])
        fields = flow.steps.first.child_flow.steps.first.fields
        fields.create title: 'user_age',   field_type: 'integer', requirements: {presence: true, minimum: 1, maximum: 150}
        fields.create title: 'user_email', field_type: 'email'
        flow.reload
      end
      let(:fields) { flow.steps.first.child_flow.steps.first.fields.all }
      let(:valid_params) do
        {step_id: flow.steps.first.child_flow.steps.first.id,
          initial_flow_id: flow.id,
          version: flow.last_version,
          fields: [
            {id: fields.first.id,  value: '18'},
            {id: fields.second.id, value: 'chapolim@chaves.com'}
        ]}
      end

      let(:kase) { Case.last }

      before do
        user.groups.first.update(permissions: user.groups.first.permissions.merge(can_execute_step: [valid_params[:step_id]]))
        post '/cases', valid_params, auth(user)
      end

      it     { expect(response.status).to be_a_requisition_created }
      it     { expect(parsed_body).to be_a_success_message_with(I18n.t(:case_created)) }
      it     { expect(parsed_body['case']).to be_an_entity_of(kase, display_type: 'full') }

      it 'should has log entries' do
        expect(kase.cases_log_entries.count).to eql 1
      end

      context 'when remove a field of step' do
        before do
          @field = flow.steps.first.child_flow.steps.first.fields.last
          delete "/flows/#{@field.step.flow.id}/steps/#{@field.step.id}/fields/#{@field.id}", {}, auth(user)
        end

        it 'should be active is false' do
          expect(@field.reload.active).to eql(false)
        end

        it 'should NOT be create a version for initial flow' do
          expect(flow.reload.versions).to be_blank
        end

        it 'should NOT be create a version for step type flow' do
          expect(flow.reload.steps.first.versions).to be_blank
        end

        it 'should be create a version for flow child of step' do
          expect(flow.reload.steps.first.child_flow.versions.count).to eql(1)
        end

        it 'should be create a version for step type form' do
          expect(flow.reload.steps.first.child_flow.steps.first.versions.count).to eql(1)
        end

        it 'should be create a version for all fields' do
          expect(@field.step.reload.fields.sum{|f| f.versions.count}).to eql(2)
        end
      end

      context 'when add more one field to step' do
        before do
          @step = flow.steps.first.child_flow.steps.first
          post "/flows/#{@step.flow.id}/steps/#{@step.id}/fields", {title: 'x', field_type:'integer'}, auth(user)
        end

        it 'should has 3 fields' do
          expect(@step.reload.fields.count).to eql(3)
        end

        it 'should NOT be create a version for initial flow' do
          expect(flow.reload.versions).to be_blank
        end

        it 'should NOT be create a version for step type flow' do
          expect(flow.reload.steps.first.versions).to be_blank
        end

        it 'should be create a version for flow child of step' do
          expect(flow.reload.steps.first.child_flow.versions.count).to eql(1)
        end

        it 'should be create a version for step type form' do
          expect(flow.reload.steps.first.child_flow.steps.first.versions.count).to eql(1)
        end

        it 'should be create a version for all fields' do
          expect(@step.reload.fields.sum{|f| f.versions.count}).to eql(2)
        end
      end
    end

    context 'when step have a trigger to disable other step' do
      let(:flow) do
        flow = create(:flow, initial: true, steps: [build(:step_type_form_without_fields), build(:step_type_form_without_fields)])
        fields = flow.steps.first.fields
        fields.create title: 'user_age',        field_type: 'integer'
        fields.create title: 'inventory_items', field_type: 'category_inventory', category_inventory_id: inventory_item.category.id, multiple: true
        fields.create title: 'size_of_tree',    field_type: 'category_inventory_field', origin_field_id: inventory_field_id
        flow.steps.first.triggers << build(:trigger, action_type: 'disable_steps', action_values: [fields.first.step.id])
        flow.reload
      end
      let(:inventory_field_id) { inventory_item.category.fields.first.id }
      let(:inventory_item)     { create(:inventory_item) }
      let(:fields)             { flow.steps.first.fields.all }
      let(:valid_params) do
        {step_id: flow.steps.first.id,
         initial_flow_id: flow.id,
         version: flow.last_version,
         fields: [{id: fields.first.id, value: '1'}, {id: fields.last.id, value: '1'}]}
      end

      let(:kase) { Case.last }

      before do
        user.groups.first.update(permissions: user.groups.first.permissions.merge(can_execute_step: [valid_params[:step_id]]))
        post '/cases', valid_params, auth(user)
      end

      it { expect(response.status).to be_a_requisition_created }
      it { expect(parsed_body).to be_a_success_message_with(I18n.t(:case_created)) }
      it { expect(parsed_body['case']).to be_an_entity_of(kase, display_type: 'full') }

      it 'should has log entries' do
        expect(kase.cases_log_entries.count).to eql 1
      end

      it 'should set the status with finished' do
        expect(kase.status).to eql 'active'
      end

      it 'should set the called trigger on CaseStep' do
        trigger = Trigger.find_by(action_type: 'disable_steps')
        expect(kase.case_steps.first.trigger_ids.first).to eql(trigger.id)
      end
    end

    context 'when step have a trigger to finish Case' do
      let(:flow) do
        flow = create(:flow, initial: true, steps: [build(:step_type_form_without_fields), build(:step_type_form_without_fields)])
        fields = flow.steps.first.fields
        fields.create title: 'user_age', field_type: 'integer'
        flow.steps.first.triggers << build(:trigger, action_type: 'finish_flow', action_values: [flow.resolution_states.first.id])
        flow.reload
      end
      let(:fields) { flow.steps.first.fields.all }
      let(:valid_params) do
        {step_id: flow.steps.first.id,
         initial_flow_id: flow.id,
         version: flow.last_version,
         fields: [{id: fields.first.id, value: '1'}]}
      end

      let(:kase) { Case.last }

      before do
        user.groups.first.update(permissions: user.groups.first.permissions.merge(can_execute_step: [valid_params[:step_id]]))
        post '/cases', valid_params, auth(user)
      end

      it { expect(response.status).to be_a_requisition_created }
      it { expect(parsed_body).to be_a_success_message_with(I18n.t(:case_created)) }
      it { expect(parsed_body['case']).to be_an_entity_of(kase, display_type: 'full') }

      it 'should has 3 log entries' do
        expect(kase.cases_log_entries.count).to eql 3
      end

      it 'should set the status with finished' do
        expect(kase.status).to eql 'finished'
      end

      it 'should set the called trigger on CaseStep' do
        trigger = Trigger.find_by(action_type: 'finish_flow')
        expect(kase.case_steps.first.trigger_ids.first).to eql(trigger.id)
      end
    end

    context 'when step have a trigger to transfer flow' do
      let(:flow) do
        flow = create(:flow, initial: true, steps: [build(:step_type_form_without_fields)])
        fields = flow.steps.first.fields
        fields.create title: 'user_age', field_type: 'integer'
        other_flow = create(:flow, initial: false, steps: [build(:step_type_form)])
        flow.steps.first.triggers << build(:trigger, action_type: 'transfer_flow', action_values: [other_flow.id])
        flow.reload
      end
      let(:fields) { flow.steps.first.fields.all }
      let(:valid_params) do
        {step_id: flow.steps.first.id,
         initial_flow_id: flow.id,
         version: flow.last_version,
         fields: [{id: fields.first.id, value: '1'}]}
      end

      let(:kase) { Case.last }

      before do
        user.groups.first.update(permissions: user.groups.first.permissions.merge(can_execute_step: [valid_params[:step_id]]))
        post '/cases', valid_params, auth(user)
      end

      it { expect(response.status).to be_a_requisition_created }
      it { expect(parsed_body).to be_a_success_message_with(I18n.t(:case_created)) }
      it { expect(parsed_body['case']).to be_an_entity_of(kase, display_type: 'full') }

      it 'should has 2 log entries' do
        expect(kase.cases_log_entries.count).to eql 2
      end

      it 'should set the status with finished' do
        expect(kase.status).to eql 'active'
      end

      it 'should set the called trigger on CaseStep' do
        trigger = Trigger.find_by(action_type: 'transfer_flow')
        expect(kase.case_steps.first.trigger_ids.first).to eql(trigger.id)
      end
    end
  end

  describe 'on get case' do
    let(:flow) do
      flow = create(:flow, initial: true, steps: [build(:step_type_form_without_fields)])
      fields = flow.steps.first.fields
      fields.create title: 'user_age', field_type: 'integer'
      other_flow = create(:flow, initial: false, steps: [build(:step_type_form)])
      flow.steps << build(:step, child_flow: other_flow)
      flow.steps.first.triggers << build(:trigger, action_type: 'disable_steps', action_values: [other_flow.steps.first.id])
      flow.reload
    end
    let(:fields) { flow.steps.first.fields.all }
    let!(:kase) do
      user.groups.first.update(permissions: user.groups.first.permissions.merge(can_execute_step: [flow.steps.first.id]))
      case_params = {step_id: flow.steps.first.id,
                     initial_flow_id: flow.id,
                     version: flow.last_version,
                     fields: [{id: fields.first.id, value: '1'}]}
      post '/cases', case_params, auth(user)
      Case.first
    end

    before { user.groups.first.update permissions: user.groups.first.permissions.merge(flow_can_view_all_steps: [flow.id]) }

    context  'no authentication' do
      before { get "/cases/#{kase.id}" }
      it     { expect(response.status).to be_an_unauthorized }
    end

    context 'with authentication' do
      context 'and user can\'t see the Step on Flow' do
        let(:error) { I18n.t(:permission_denied, action: I18n.t(:show), table_name: I18n.t(:cases)) }

        before { get "/cases/#{kase.id}", {}, auth(guest_user) }
        it     { expect(response.status).to be_a_forbidden }
        it     { expect(parsed_body).to be_an_error(error) }
      end

      context 'and user can execute first Step on Flow' do
        context 'and failure' do
          context 'because case not found' do
            before { get '/cases/123456789', {}, auth(user) }
            it     { expect(response.status).to be_a_not_found }
            it     { expect(parsed_body).to be_an_error('Couldn\'t find Case with id=123456789 [WHERE (status != \'inactive\')]') }
          end
        end

        context 'successfully' do
          context 'with display_type is full'do
            before do
              # set manage_flows=false to realy test Case permissions
              user.groups.first.update permissions: user.groups.first.permissions.merge('manage_flows' => false)
              get "/cases/#{kase.id}", {display_type: 'full'}, auth(user)
            end

            it { expect(response.status).to be_a_success_request }
            it { expect(parsed_body['case']).to be_an_entity_of(kase, display_type: 'full', just_user_can_view: true, current_user: user) }

            it 'should has disabled steps' do
              expect(parsed_body['case']['disabled_steps']).to eql([Flow.last.steps.first.id])
            end
          end

          context 'with display_type isn\'t full'do
            before { get "/cases/#{kase.id}", {}, auth(user) }
            it     { expect(response.status).to be_a_success_request }
            it     { expect(parsed_body['case']).to be_an_entity_of(kase) }

            it 'should has disabled steps' do
              expect(parsed_body['case']['disabled_steps']).to eql([Flow.last.steps.first.id])
            end
          end
        end
      end
    end
  end

  describe 'on put case' do
    context 'when has step disabled' do
      let(:flow) do
        flow = create(:flow, initial: true, steps: [build(:step_type_form_without_fields),build(:step_type_form)])
        fields = flow.steps.first.fields
        fields.create title: 'user_age', field_type: 'integer'
        other_flow = create(:flow, initial: false, steps: [build(:step_type_form)])
        flow.steps << build(:step, child_flow: other_flow)
        flow.steps.first.triggers << build(:trigger, action_type: 'disable_steps', action_values: [flow.steps.second.id],
                                           trigger_conditions: [build(:trigger_condition, values: [1], field: fields.first)])
        flow.steps.first.triggers << build(:trigger, action_type: 'finish_flow', action_values: [flow.resolution_states.first.id],
                                           trigger_conditions: [build(:trigger_condition, values: [10], field: fields.first)])
        flow.reload
      end
      let(:fields) { flow.steps.first.fields.all }
      let(:other_step) { Flow.first.steps.second }
      let(:valid_params) do
        {step_id: other_step.id,
          step_version: other_step.last_version,
          fields: [{id: fields.first.id, value: '1'}]}
      end
      let(:other_flow_valid_params) do
        {step_id: Flow.last.steps.last.id,
          step_version: Flow.last.steps.last.last_version,
          fields: [{id: Flow.last.steps.last.fields.first.id, value: '1'}]}
      end
      let!(:kase) do
        case_params = {step_id: flow.steps.first.id,
          initial_flow_id: flow.id,
          version: flow.last_version,
          fields: [{id: fields.first.id, value: '1'}]}
        user.groups.first.update permissions: user.groups.first.permissions.merge(can_execute_step: [case_params[:step_id]])
        post '/cases', case_params, auth(user)
        Case.first
      end

      context  'no authentication' do
        before { put "/cases/#{kase.id}", valid_params }
        it     { expect(response.status).to be_an_unauthorized }
      end

      context 'with authentication' do
        context 'and user can\'t see the Step on Flow' do
          let(:error) { I18n.t(:permission_denied, action: I18n.t(:create), table_name: I18n.t(:case_steps)) }

          before { put "/cases/#{kase.id}", other_flow_valid_params, auth(guest_user) }
          it     { expect(response.status).to be_a_forbidden }
          it     { expect(parsed_body).to be_an_error(error) }
        end

        context 'and user can see the Step on Flow' do
          context 'and failure' do
            context 'because case not found' do
              before { put '/cases/123456789', valid_params, auth(user) }
              it     { expect(response.status).to be_a_not_found }
              it     { expect(parsed_body).to be_an_error('Couldn\'t find Case with id=123456789 [WHERE (status != \'inactive\')]') }
            end

            context 'because step is disabled' do
              before { put "/cases/#{kase.id}", valid_params, auth(user) }
              it     { expect(response.status).to be_a_bad_request }
              it     { expect(parsed_body).to be_an_error(I18n.t(:step_is_disabled)) }
            end
          end

          context 'successfully' do
            let(:success_params) { valid_params.merge(step_id: fields.first.step.id, fields: [{id: fields.first.id, value: '10'}]) }
            before do
              user.groups.first.update permissions: user.groups.first.permissions.merge(can_execute_step: [flow.steps.first.id])
              put "/cases/#{kase.id}", valid_params, auth(user)
              put "/cases/#{kase.id}", success_params, auth(user)
            end
            it     { expect(response.status).to be_a_success_request }
            it     { expect(parsed_body).to be_a_success_message_with(I18n.t(:update_step_success)) }
            it     { expect(parsed_body['case']).to be_an_entity_of(kase.reload, display_type: 'full') }

            it 'should finish the Case' do
              expect(kase.reload.status).to eql('finished')
            end

            it 'should has 4 log entries' do
              expect(kase.reload.cases_log_entries.count).to eql 4
            end
          end
        end
      end
    end

    context 'when not has trigger' do
      let(:flow) do
        flow = create(:flow, initial: true, steps: [build(:step_type_form_without_fields)])
        fields = flow.steps.first.fields
        fields.create title: 'user_age', field_type: 'integer'
        other_flow = create(:flow, initial: false, steps: [build(:step_type_form)])
        flow.steps << build(:step, child_flow: other_flow)
        flow.reload
      end
      let(:fields) { flow.steps.first.fields.all }
      let(:other_step) { Flow.last.steps.first }
      let(:valid_params) do
        {step_id: other_step.id,
          step_version: other_step.last_version,
          fields: [{id: fields.first.id, value: '1'}]}
      end
      let!(:kase) do
        case_params = {step_id: flow.steps.first.id,
          initial_flow_id: flow.id,
          version: flow.last_version,
          fields: [{id: fields.first.id, value: '1'}]}
        user.groups.first.update permissions: user.groups.first.permissions.merge(can_execute_step: [case_params[:step_id]])
        post '/cases', case_params, auth(user)
        Case.first
      end

      before { user.groups.first.update permissions: user.groups.first.permissions.merge(can_execute_step: [valid_params[:step_id]]) }

      context  'no authentication' do
        before { put "/cases/#{kase.id}", valid_params }
        it     { expect(response.status).to be_an_unauthorized }
      end

      context 'with authentication' do
        context 'and user can\'t see the Step on Flow' do
          let(:error) { I18n.t(:permission_denied, action: I18n.t(:create), table_name: I18n.t(:case_steps)) }

          before { put "/cases/#{kase.id}", valid_params, auth(guest_user) }
          it     { expect(response.status).to be_a_forbidden }
          it     { expect(parsed_body).to be_an_error(error) }
        end

        context 'and user can execute first Step on Flow' do
          context 'and failure' do
            context 'because case not found' do
              before { put '/cases/123456789', valid_params, auth(user) }
              it     { expect(response.status).to be_a_not_found }
              it     { expect(parsed_body).to be_an_error('Couldn\'t find Case with id=123456789 [WHERE (status != \'inactive\')]') }
            end
          end

          context 'successfully' do
            before { put "/cases/#{kase.id}", valid_params, auth(user) }
            it     { expect(response.status).to be_a_success_request }
            it     { expect(parsed_body['case']).to be_an_entity_of(kase.reload, display_type: 'full') }

            it 'should has empty disabled steps' do
              expect(parsed_body['case']['disabled_steps']).to be_blank
            end
          end
        end
      end
    end

    context 'when update a case step' do
      let(:flow) do
        flow = create(:flow, initial: true, steps: [build(:step_type_form_without_fields)])
        fields = flow.steps.first.fields
        fields.create title: 'user_age', field_type: 'integer'
        fields.create title: 'inventory_items', field_type: 'category_inventory', category_inventory_id: inventory_item.category.id, multiple: true
        fields.create title: 'size_of_tree',    field_type: 'category_inventory_field', origin_field_id: inventory_field_id
        other_flow = create(:flow, initial: false, steps: [build(:step_type_form)])
        flow.steps << build(:step, child_flow: other_flow)
        flow.reload
      end
      let(:inventory_field_id) { inventory_item.category.fields.first.id }
      let!(:inventory_item)    { create(:inventory_item) }
      let(:inventory_value)    { '-123' }
      let(:fields) { flow.steps.first.fields.all }
      let(:valid_params) do
        {step_id: flow.steps.first.id,
          step_version: flow.steps.first.last_version,
          fields: [
            {id: fields.first.id,  value: '10'},
            {id: fields.second.id, value: [inventory_item.id]},
            {id: fields.third.id,  value: inventory_value},
        ]}
      end
      let!(:kase) do
        case_params = {step_id: flow.steps.first.id,
          initial_flow_id: flow.id,
          version: flow.last_version,
          fields: [{id: fields.first.id, value: '1'}]}
        user.groups.first.update permissions: user.groups.first.permissions.merge(can_execute_step: [case_params[:step_id]])
        post '/cases', case_params, auth(user)
        Case.first
      end

      before { user.groups.first.update permissions: user.groups.first.permissions.merge(can_execute_step: [valid_params[:step_id]]) }

      context  'no authentication' do
        before { put "/cases/#{kase.id}", valid_params }
        it     { expect(response.status).to be_an_unauthorized }
      end

      context 'with authentication' do
        context 'and user can\'t see the Step on Flow' do
          let(:error) { I18n.t(:permission_denied, action: I18n.t(:update), table_name: I18n.t(:case_steps)) }

          before { put "/cases/#{kase.id}", valid_params, auth(guest_user) }
          it     { expect(response.status).to be_a_forbidden }
          it     { expect(parsed_body).to be_an_error(error) }
        end

        context 'and user can execute first Step on Flow' do
          context 'and failure' do
            context 'because case not found' do
              before { put '/cases/123456789', valid_params, auth(user) }
              it     { expect(response.status).to be_a_not_found }
              it     { expect(parsed_body).to be_an_error('Couldn\'t find Case with id=123456789 [WHERE (status != \'inactive\')]') }
            end
          end

          context 'successfully' do
            let!(:inventory) { inventory_item.data.find_by(inventory_field_id: inventory_field_id) }
            before { put "/cases/#{kase.id}", valid_params, auth(user) }
            it     { expect(response.status).to be_a_success_request }
            it     { expect(parsed_body['case']).to be_an_entity_of(kase.reload, display_type: 'full') }

            it 'case step data should be updated' do
              body_data = parsed_body['case']['current_step']['case_step_data_fields'].first['value']
              expect(body_data).to eql('10')
            end

            it 'should has empty disabled steps' do
              expect(parsed_body['case']['disabled_steps']).to be_blank
            end

            it 'should update field on Inventory' do
              expect(inventory.reload.content.to_f).to eql inventory_value.to_f
            end
          end
        end
      end
    end

    context 'when case is finished (by trigger)' do
      let(:flow) do
        flow = create(:flow, initial: true, steps: [build(:step_type_form_without_fields)], resolution_states: [build(:resolution_state, default: true)])
        fields = flow.steps.first.fields
        fields.create title: 'user_age', field_type: 'integer'
        other_flow = create(:flow, initial: false, steps: [build(:step_type_form)])
        flow.steps << build(:step, child_flow: other_flow)
        flow.steps.first.triggers << build(:trigger, action_type: 'finish_flow', action_values: [flow.resolution_states.first.id])
        flow.reload
      end
      let(:fields) { flow.steps.first.fields.all }
      let(:valid_params) do
        {step_id: flow.steps.first.id,
          step_version: flow.steps.first.last_version,
          fields: [{id: fields.first.id, value: '10'}]}
      end
      let!(:kase) do
        case_params = {step_id: flow.steps.first.id,
          initial_flow_id: flow.id,
          version: flow.last_version,
          fields: [{id: fields.first.id, value: '1'}]}
        user.groups.first.update permissions: user.groups.first.permissions.merge(can_execute_step: [case_params[:step_id]])
        post '/cases', case_params, auth(user)
        Case.first
      end

      before { user.groups.first.update permissions: user.groups.first.permissions.merge(can_execute_step: [valid_params[:step_id]]) }

      context  'no authentication' do
        before { put "/cases/#{kase.id}", valid_params }
        it     { expect(response.status).to be_an_unauthorized }
      end

      context 'with authentication' do
        context 'and user can\'t see the Step on Flow' do
          let(:error) { I18n.t(:permission_denied, action: I18n.t(:update), table_name: I18n.t(:case_steps)) }

          before { put "/cases/#{kase.id}", valid_params, auth(guest_user) }
          it     { expect(response.status).to be_a_not_allowed_method }
          it     { expect(parsed_body).to be_an_error(I18n.t(:case_is_finished)) }
        end

        context 'and user can execute first Step on Flow' do
          context 'and failure' do
            context 'because case not found' do
              before { put '/cases/123456789', valid_params, auth(user) }
              it     { expect(response.status).to be_a_not_found }
              it     { expect(parsed_body).to be_an_error('Couldn\'t find Case with id=123456789 [WHERE (status != \'inactive\')]') }
            end

            context 'because case is finished' do
              before { put "/cases/#{kase.id}", valid_params, auth(user) }
              it     { expect(response.status).to be_a_not_allowed_method }
              it     { expect(parsed_body).to be_an_error(I18n.t(:case_is_finished)) }
            end
          end
        end
      end
    end
  end

  describe 'to finish' do
    context 'when have one step filled' do
      let(:flow) do
        flow = create(:flow, initial: true, steps: [build(:step_type_form_without_fields)], resolution_states: [build(:resolution_state, default: true)])
        fields = flow.steps.first.fields
        fields.create title: 'user_age', field_type: 'integer'
        other_flow = create(:flow, initial: false, steps: [build(:step_type_form)])
        flow.steps << build(:step, child_flow: other_flow)
        flow.reload
      end
      let(:fields) { flow.steps.first.fields.all }
      let(:valid_params) do
        {step_id: flow.steps.first.id,
         step_version: flow.steps.first.last_version,
         fields: [{id: fields.first.id, value: '10'}]}
      end
      let!(:kase) do
        case_params = {step_id: flow.steps.first.id,
          initial_flow_id: flow.id,
          version: flow.last_version,
          fields: [{id: fields.first.id, value: '1'}]}
        user.groups.first.update permissions: user.groups.first.permissions.merge(can_execute_step: [case_params[:step_id]])
        post '/cases', case_params, auth(user)
        Case.first
      end

      context  'no authentication' do
        before { put "/cases/#{kase.id}/finish", {resolution_state_id: 123} }
        it     { expect(response.status).to be_an_unauthorized }
      end

      context 'with authentication' do
        context 'and user can\'t update the Case' do
          let(:error) { I18n.t(:permission_denied, action: I18n.t(:update), table_name: I18n.t(:cases)) }

          before { put "/cases/#{kase.id}/finish", {resolution_state_id: 123}, auth(guest_user) }
          it     { expect(response.status).to be_a_forbidden }
          it     { expect(parsed_body).to be_an_error(error) }
        end

        context 'and user can execute first Step on Flow' do
          context 'and failure' do
            context 'because case not found' do
              before { put '/cases/123456789/finish', {resolution_state_id: 123}, auth(user) }
              it     { expect(response.status).to be_a_not_found }
              it     { expect(parsed_body).to be_an_error('Couldn\'t find Case with id=123456789 [WHERE (status != \'inactive\')]') }
            end
          end

          context 'successfully' do
            context 'when Case is already finished' do
              before do
                kase.update(status: 'finished', resolution_state_id: flow.resolution_states.first.id)
                put "/cases/#{kase.id}/finish", {resolution_state_id: 123}, auth(user)
              end

              it { expect(response.status).to be_a_success_request }
              it { expect(parsed_body).to be_a_success_message_with(I18n.t(:case_is_already_finished)) }

              it 'should Case status is finished' do
                expect(kase.reload.status).to eql('finished')
              end
            end

            context 'when Case isn\'t finished' do
              before { put "/cases/#{kase.id}/finish", {resolution_state_id: flow.resolution_states.first.id}, auth(user) }
              it     { expect(response.status).to be_a_success_request }
              it     { expect(parsed_body).to be_a_success_message_with(I18n.t(:finished_case)) }

              it 'should Case status is finished' do
                expect(kase.reload.status).to eql('finished')
              end
            end
          end
        end
      end
    end
  end

  describe 'to update CaseStep' do
    let(:flow) do
      flow = create(:flow, initial: true, steps: [build(:step_type_form_without_fields)])
      fields = flow.steps.first.fields
      fields.create title: 'user_age', field_type: 'integer'
      other_flow = create(:flow, initial: false, steps: [build(:step_type_form)])
      flow.steps << build(:step, child_flow: other_flow)
      flow.reload
    end
    let(:fields) { flow.steps.first.fields.all }
    let(:valid_params) do
      {step_id: flow.steps.first.id,
       step_version: flow.steps.first.last_version,
       fields: [{id: fields.first.id, value: '10'}]}
    end
    let!(:kase) do
      case_params = {step_id: flow.steps.first.id,
        initial_flow_id: flow.id,
        version: flow.last_version,
        fields: [{id: fields.first.id, value: '1'}]}
      user.groups.first.update permissions: user.groups.first.permissions.merge(can_execute_step: [case_params[:step_id]])
      post '/cases', case_params, auth(user)
      Case.first
    end

    before { user.groups.first.update permissions: user.groups.first.permissions.merge(can_execute_step: [valid_params[:step_id]]) }

    context  'no authentication' do
      before { put "/cases/#{kase.id}/case_steps/#{kase.case_steps.last.id}" }
      it     { expect(response.status).to be_an_unauthorized }
    end

    context 'with authentication' do
      context 'and user can\'t update the Case' do
        let(:error) { I18n.t(:permission_denied, action: I18n.t(:update), table_name: I18n.t(:case_steps)) }

        before { put "/cases/#{kase.id}/case_steps/#{kase.case_steps.last.id}", {}, auth(guest_user) }
        it     { expect(response.status).to be_a_forbidden }
        it     { expect(parsed_body).to be_an_error(error) }
      end

      context 'and user can update the Case' do
        context 'and failure' do
          context 'because case not found' do
            before { put "/cases/#{kase.id}/case_steps/123456789", {}, auth(user) }
            it     { expect(response.status).to be_a_not_found }
            it     { expect(parsed_body).to be_an_error('Couldn\'t find CaseStep with id=123456789') }
          end
        end

        context 'successfully' do
          context 'when set responsible_user_id' do
            before { put "/cases/#{kase.id}/case_steps/#{kase.case_steps.last.id}", {responsible_user_id: nil}, auth(user) }
            it     { expect(response.status).to be_a_success_request }
            it     { expect(parsed_body).to be_a_success_message_with(I18n.t(:case_step_updated)) }

            it 'should responsible_user_id be blank' do
              expect(kase.case_steps.last.responsible_user_id).to be_blank
            end

            it 'should has log entries' do
              expect(kase.cases_log_entries.count).to eql 2
            end
          end

          context 'when set responsible_user_id and responsible_group_id' do
            let(:valid_params1) { {responsible_user_id: nil, responsible_group_id: user.groups.first.id} }

            before { put "/cases/#{kase.id}/case_steps/#{kase.case_steps.last.id}", valid_params1, auth(user) }
            it     { expect(response.status).to be_a_success_request }
            it     { expect(parsed_body).to be_a_success_message_with(I18n.t(:case_step_updated)) }

            it 'should responsible_user_id be blank' do
              expect(kase.case_steps.last.responsible_user_id).to eql(valid_params1[:responsible_user_id])
            end

            it 'should responsible_group_id be group id' do
              expect(kase.case_steps.last.responsible_group_id).to eql(valid_params1[:responsible_group_id])
            end

            it 'should has log entries' do
              expect(kase.cases_log_entries.count).to eql 2
            end
          end
        end
      end
    end
  end

  describe 'to get all cases' do
    let(:other_user) { create(:user) }
    let(:other_flow) do
      flow = create(:flow, title: 'Other', initial: true, steps: [build(:step_type_form_without_fields), build(:step_type_form)])
      flow.steps.first.fields.create title: 'company_age', field_type: 'integer'
      flow
    end
    let(:flow) do
      flow = create(:flow, initial: true, steps: [build(:step_type_form_without_fields), build(:step_type_form)])
      flow.steps.first.fields.create title: 'user_age', field_type: 'integer'
      flow
    end
    let!(:kase1) do
      case_params = {step_id: flow.steps.first.id, initial_flow_id: flow.id,
                     version: flow.last_version, fields: [{id: flow.steps.first.fields.first.id, value: '1'}]}
      add_can_execute_step(user, case_params[:step_id])
      post '/cases', case_params, auth(user)
      Case.last
    end
    let!(:kase2) do
      case_params = {step_id: other_flow.steps.first.id, initial_flow_id: other_flow.id,
                     version: other_flow.last_version, fields: [{id: other_flow.steps.first.fields.first.id, value: '2'}]}
      add_can_execute_step(user, case_params[:step_id])
      post '/cases', case_params, auth(user)
      Case.last
    end
    let!(:kase3) do
      case_params = {step_id: flow.steps.first.id, initial_flow_id: flow.id,
                     version: flow.last_version, fields: [{id: flow.steps.first.fields.first.id, value: '3'}]}
      add_can_execute_step(other_user, case_params[:step_id])
      post '/cases', case_params, auth(other_user)
      Case.last
    end

    before do
      user.groups.first.update       permissions: user.groups.first.permissions.merge('manage_flows' => false)
      other_user.groups.first.update permissions: other_user.groups.first.permissions.merge('manage_flows' => false)
    end

    context 'no authentication' do
      before { get '/cases' }
      it     { expect(response.status).to be_an_unauthorized }
    end

    context 'with authentication' do
      context 'with filter by initial_flow_id' do
        let(:case_ids) { parsed_body['cases'].map { |k| k['id'] } }
        before { get '/cases', {initial_flow_id: flow.id.to_s}, auth(user) }
        it     { expect(response.status).to be_a_success_request }
        it     { expect(parsed_body['cases'].count).to eql 2 }
        it     { expect(case_ids).to include kase1.id }
        it     { expect(case_ids).to_not include kase2.id }
        it     { expect(case_ids).to include kase3.id }
      end

      context 'with filter by step_id' do
        let(:case_ids) { parsed_body['cases'].map { |k| k['id'] } }
        before { get '/cases', {step_id: other_flow.steps.first.id.to_s}, auth(user) }
        it     { expect(response.status).to be_a_success_request }
        it     { expect(parsed_body['cases'].count).to eql 1 }
        it     { expect(case_ids).to_not include kase1.id }
        it     { expect(case_ids).to include kase2.id }
        it     { expect(case_ids).to_not include kase3.id }
      end

      context 'with filter by responsible_group_id' do
        let(:case_ids) { parsed_body['cases'].map { |k| k['id'] } }
        before do
          add_can_execute_step(user, kase1.case_steps.first.step.id)
          put "/cases/#{kase1.id}/case_steps/#{kase1.case_steps.first.id}", {responsible_group_id: user.groups.first.id}, auth(user)
          get '/cases', {responsible_group_id: user.groups.first.id.to_s}, auth(user)
        end

        it { expect(response.status).to be_a_success_request }
        it { expect(parsed_body['cases'].count).to eql 1 }
        it { expect(case_ids).to include kase1.id }
        it { expect(case_ids).to_not include kase2.id }
        it { expect(case_ids).to_not include kase3.id }
      end

      context 'with filter by responsible_user_id' do
        let(:case_ids) { parsed_body['cases'].map { |k| k['id'] } }
        before do
          add_can_execute_step(user, kase1.case_steps.first.step.id)
          put "/cases/#{kase1.id}/case_steps/#{kase1.case_steps.first.id}", {responsible_user_id: user.id+1}, auth(user)
          get '/cases', {responsible_user_id: user.id.to_s}, auth(user)
        end

        it { expect(response.status).to be_a_success_request }
        it { expect(parsed_body['cases'].count).to eql 1 }
        it { expect(case_ids).to_not include kase1.id }
        it { expect(case_ids).to include kase2.id }
        it { expect(case_ids).to_not include kase3.id }
      end

      context 'with filter by created_by_id' do
        let(:case_ids) { parsed_body['cases'].map { |k| k['id'] } }
        before { get '/cases', {created_by_id: user.id.to_s}, auth(user) }
        it     { expect(response.status).to be_a_success_request }
        it     { expect(parsed_body['cases'].count).to eql 2 }
        it     { expect(case_ids).to include kase1.id }
        it     { expect(case_ids).to include kase2.id }
        it     { expect(case_ids).to_not include kase3.id }
      end

      context 'with filter by updated_by_id' do
        let(:case_ids) { parsed_body['cases'].map { |k| k['id'] } }
        before do
          add_can_execute_step(user, kase1.case_steps.first.step.id)
          put "/cases/#{kase1.id}/case_steps/#{kase1.case_steps.first.id}", {responsible_user_id: user.id}, auth(user)
          get '/cases', {updated_by_id: user.id.to_s}, auth(user)
        end

        it { expect(response.status).to be_a_success_request }
        it { expect(parsed_body['cases'].count).to eql 1 }
        it { expect(case_ids).to include kase1.id }
        it { expect(case_ids).to_not include kase2.id }
        it { expect(case_ids).to_not include kase3.id }
      end

      context 'without filter' do
        context 'when user can see all items' do
          context 'when not use display_type full' do
            before { get '/cases', {}, auth(user) }
            it     { expect(response.status).to be_a_success_request }
            it     { expect(parsed_body['cases'].count).to eql 3 }
            it     { expect(parsed_body['cases']).to include_an_entity_of(kase1, just_user_can_view: true, current_user: user) }
            it     { expect(parsed_body['cases']).to include_an_entity_of(kase2, just_user_can_view: true, current_user: user) }
            it     { expect(parsed_body['cases']).to include_an_entity_of(kase3, just_user_can_view: true, current_user: user) }

            it 'should see only the cases_step ids' do
              kase = parsed_body['cases'].first
              expect(kase['case_step_ids']).to be_present
            end
          end

          context 'when use display_type full' do
            before { get '/cases', {display_type: 'full'}, auth(user) }
            it     { expect(response.status).to be_a_success_request }
            it     { expect(parsed_body['cases'].count).to eql 3 }
            it     { expect(parsed_body['cases']).to include_an_entity_of(kase1, display_type: 'full', just_user_can_view: true, current_user: user) }
            it     { expect(parsed_body['cases']).to include_an_entity_of(kase2, display_type: 'full', just_user_can_view: true, current_user: user) }
            it     { expect(parsed_body['cases']).to include_an_entity_of(kase3, display_type: 'full', just_user_can_view: true, current_user: user) }

            it 'should see the cases_step objects' do
              kase = parsed_body['cases'].first
              expect(kase['case_step_ids']).to  be_present
              expect(kase['current_step']).to   be_present
            end
          end

          context 'when use paginate 1 by page' do
            context 'in page 1' do
              before { get '/cases', {page: 1, per_page: 1}, auth(user) }
              it     { expect(response.status).to be_a_success_request }
              it     { expect(parsed_body['cases'].count).to eql 1 }
              it     { expect(parsed_body['cases']).to include_an_entity_of(kase1, just_user_can_view: true, current_user: user) }
              it     { expect(parsed_body['cases']).to_not include_an_entity_of(kase2, just_user_can_view: true, current_user: user) }
              it     { expect(parsed_body['cases']).to_not include_an_entity_of(kase3, just_user_can_view: true, current_user: user) }
            end

            context 'in page 2' do
              before { get '/cases', {page: 2, per_page: 1}, auth(user) }
              it     { expect(response.status).to be_a_success_request }
              it     { expect(parsed_body['cases'].count).to eql 1 }
              it     { expect(parsed_body['cases']).to_not include_an_entity_of(kase1, just_user_can_view: true, current_user: user) }
              it     { expect(parsed_body['cases']).to include_an_entity_of(kase2, just_user_can_view: true, current_user: user) }
              it     { expect(parsed_body['cases']).to_not include_an_entity_of(kase3, just_user_can_view: true, current_user: user) }
            end
          end
        end
      end
    end
  end

  describe 'to transfer Case' do
    let(:flow) do
      flow = create(:flow, initial: true, steps: [build(:step_type_form_without_fields)])
      flow.steps.first.fields.create title: 'user_age', field_type: 'integer'
      flow.reload
    end
    let(:other_flow) { create(:flow, steps: [build(:step_type_form)]) }
    let(:fields)     { flow.steps.first.fields.all }
    let(:valid_params) do
      {step_id: flow.steps.first.id,
        step_version: flow.steps.first.last_version,
        fields: [{id: fields.first.id, value: '10'}]}
    end
    let!(:kase) do
      case_params = {step_id: flow.steps.first.id,
        initial_flow_id: flow.id,
        version: flow.last_version,
        fields: [{id: fields.first.id, value: '1'}]}
      user.groups.first.update permissions: user.groups.first.permissions.merge(can_execute_step: [case_params[:step_id]])
      post '/cases', case_params, auth(user)
      Case.first
    end

    context  'no authentication' do
      before { put "/cases/#{kase.id}/transfer", {flow_id: other_flow.id} }
      it     { expect(response.status).to be_an_unauthorized }
    end

    context 'with authentication' do
      context 'and user can\'t update the Case' do
        let(:error) { I18n.t(:permission_denied, action: I18n.t(:update), table_name: I18n.t(:cases)) }

        before { put "/cases/#{kase.id}/transfer", {flow_id: other_flow.id}, auth(guest_user) }
        it     { expect(response.status).to be_a_forbidden }
        it     { expect(parsed_body).to be_an_error(error) }
      end

      context 'and user can update the Case' do
        context 'and failure' do
          context 'because case not found' do
            before { put '/cases/123456789/transfer', {flow_id: other_flow.id}, auth(user) }
            it     { expect(response.status).to be_a_not_found }
            it     { expect(parsed_body).to be_an_error('Couldn\'t find Case with id=123456789 [WHERE (status != \'inactive\')]') }
          end
        end

        context 'successfully' do
          let(:new_kase) { Case.find_by(original_case_id: kase.id) }
          before { put "/cases/#{kase.id}/transfer", {flow_id: other_flow.id}, auth(user) }
          it     { expect(response.status).to be_a_success_request }
          it     { expect(parsed_body).to be_a_success_message_with(I18n.t(:case_updated)) }
          it     { expect(parsed_body['case']).to be_an_entity_of(new_kase) }
          it     { expect(parsed_body['case']['original_case_id']).to eql(kase.id) }

          it 'should old Case status is transfer' do
            expect(kase.reload.status).to eql('transfer')
          end

          it 'should has old log entries' do
            expect(kase.cases_log_entries.count).to eql 2
          end

          it 'should new Case status is active' do
            expect(new_kase.reload.status).to eql('active')
          end

          it 'should has new log entries' do
            expect(new_kase.cases_log_entries.count).to eql 1
          end
        end
      end
    end
  end

  describe 'to inactive Case' do
    let(:flow) do
      flow = create(:flow, initial: true, steps: [build(:step_type_form_without_fields)])
      flow.steps.first.fields.create title: 'user_age', field_type: 'integer'
      flow.reload
    end
    let!(:kase) do
      case_params = {step_id: flow.steps.first.id,
        initial_flow_id: flow.id,
        version: flow.last_version,
        fields: [{id: flow.steps.first.fields.first.id, value: '1'}]}
      user.groups.first.update permissions: user.groups.first.permissions.merge(can_execute_step: [case_params[:step_id]])
      post '/cases', case_params, auth(user)
      Case.first
    end

    before { user.groups.first.update permissions: user.groups.first.permissions.merge(flow_can_delete_own_cases: true) }

    context  'no authentication' do
      before { delete "/cases/#{kase.id}" }
      it     { expect(response.status).to be_an_unauthorized }
    end

    context 'with authentication' do
      context 'and user can\'t delete the Case' do
        let(:error) { I18n.t(:permission_denied, action: I18n.t(:delete), table_name: I18n.t(:cases)) }

        before { delete "/cases/#{kase.id}", {}, auth(guest_user) }
        it     { expect(response.status).to be_a_forbidden }
        it     { expect(parsed_body).to be_an_error(error) }
      end

      context 'and user can delete the Case' do
        context 'and failure' do
          context 'because case not found' do
            before { delete '/cases/123456789', {}, auth(user) }
            it     { expect(response.status).to be_a_not_found }
            it     { expect(parsed_body).to be_an_error('Couldn\'t find Case with id=123456789 [WHERE "cases"."status" IN (\'active\', \'pending\', \'transfer\')]') }
          end
        end

        context 'successfully' do
          before { delete "/cases/#{kase.id}", {}, auth(user) }
          it     { expect(response.status).to be_a_success_request }
          it     { expect(parsed_body).to be_a_success_message_with(I18n.t(:case_deleted)) }

          it 'should Case status is inactive' do
            expect(kase.reload.status).to eql('inactive')
          end

          it 'should has a last log entries with action=delete_case' do
            expect(kase.cases_log_entries.last.action).to eql 'delete_case'
          end
        end
      end
    end
  end

  describe 'to restore Case' do
    let(:flow) do
      flow = create(:flow, initial: true, steps: [build(:step_type_form_without_fields)])
      flow.steps.first.fields.create title: 'user_age', field_type: 'integer'
      flow.reload
    end
    let!(:kase) do
      user.groups.first.update(permissions: user.groups.first.permissions.merge(flow_can_delete_own_cases: true))
      case_params = {step_id: flow.steps.first.id,
        initial_flow_id: flow.id,
        version: flow.last_version,
        fields: [{id: flow.steps.first.fields.first.id, value: '1'}]}
      user.groups.first.update permissions: user.groups.first.permissions.merge(can_execute_step: [case_params[:step_id]])
      post '/cases', case_params, auth(user)
      kase = Case.first
      delete "/cases/#{kase.id}", {}, auth(user)
      kase.reload
    end

    context  'no authentication' do
      before { put "/cases/#{kase.id}/restore" }
      it     { expect(response.status).to be_an_unauthorized }
    end

    context 'with authentication' do
      context 'and user can\'t delete the Case' do
        let(:error) { I18n.t(:permission_denied, action: I18n.t(:restore), table_name: I18n.t(:cases)) }

        before { put "/cases/#{kase.id}/restore", {}, auth(guest_user) }
        it     { expect(response.status).to be_a_forbidden }
        it     { expect(parsed_body).to be_an_error(error) }
      end

      context 'and user can delete the Case' do
        context 'and failure' do
          context 'because case not found' do
            before { put '/cases/123456789/restore', {}, auth(user) }
            it     { expect(response.status).to be_a_not_found }
            it     { expect(parsed_body).to be_an_error('Couldn\'t find Case with id=123456789 [WHERE "cases"."status" = \'inactive\']') }
          end
        end

        context 'successfully' do
          before { put "/cases/#{kase.id}/restore", {}, auth(user) }
          it     { expect(response.status).to be_a_success_request }
          it     { expect(parsed_body).to be_a_success_message_with(I18n.t(:case_restored)) }

          it 'should Case status is active' do
            expect(kase.reload.status).to eql('active')
          end

          it 'should has a last log entries with action=restored_case' do
            expect(kase.cases_log_entries.last.action).to eql 'restored_case'
          end
        end
      end
    end
  end
end
