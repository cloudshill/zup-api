module Groups
  class API < Grape::API
    resources :groups do
      desc "List all groups"
      paginate per_page: 25
      params do
        optional :name, type: String, desc: "Name of the group"
        optional :user_name, type: String, desc: "Name of the user"
        optional :display_users, type: Boolean, desc: "Sets if should display users or not"
      end
      get do
        authenticate!
        validate_permission!(:view, Group)

        search_params = safe_params.permit(:name, :user_name)

        user_name = search_params.delete(:user_name)
        group_name = search_params.delete(:name)

        search_query = {}

        if group_name
          search_query = search_query.merge(name: group_name)
        end

        if user_name
          search_query = search_query.merge(users: { name: user_name })
        end

        if search_query.empty?
          groups = paginate(Group.all)
        else
          # TODO: Fix the pagination for this query
          # it's an incompatibility between
          # will_paginate and textacular.
          groups = Group.includes(:users)
                        .advanced_search(search_query, false)
        end

        {
          groups: Group::Entity.represent(
            groups,
            display_users: safe_params[:display_users]
          )
        }
      end

      desc "Create a group"
      params do
        requires :name, type: String, desc: "Group's name"
        requires :permissions, type: Hash, desc: "Group's permissions (add_users, view_categories, view_sections)"
        optional :description, type: String, desc: "Group's description"
        optional :users, type: Array, desc: "Array of users id to add to the user"
      end
      post do
        authenticate!
        validate_permission!(:create, Group)

        group_params = safe_params.permit(:name, :description)
        group_params[:permissions] = safe_params[:permissions] if safe_params[:permissions]

        group = Group.create!(group_params)

        if safe_params[:users].present?
          users = User.where(id: safe_params[:users].map(&:to_i))
          group.users = users
        end

        group.save!

        { message: "Group created successfully", group: Group::Entity.represent(group) }
      end

      desc "Shows group info"
      params do
        optional :display_users, type: Boolean, desc: "Sets if should display all group users or not"
      end
      get ':id' do
        group = Group.find_by(id: safe_params[:id])
        validate_permission!(:view, group)

        if group
          {
            group: Group::Entity.represent(
              group, display_users: safe_params[:display_users])
          }
        else
          error!("Group not found", 404)
        end
      end

      desc "Destroy group"
      delete ':id' do
        authenticate!
        group = Group.find_by(id: safe_params[:id])

        if group && group.destroy
          { message: "Group destroyed sucessfully" }
        else
          error!("Group not found", 404)
        end
      end

      desc "Update group's info"
      params do
        optional :name, type: String, desc: "Group's name"
        optional :description, type: String, desc: "Group's description"
        optional :permissions, type: Hash, desc: "Group's permissions (add_users, view_categories, view_sections)"
        optional :users, type: Array, desc: "Array of users id to add to the user"
      end
      put ":id" do
        authenticate!
        group = Group.find(safe_params[:id])
        validate_permission!(:update, group)

        group.name = safe_params[:name] if safe_params[:name]
        group.description = safe_params[:description] if safe_params[:description]
        group.permissions = safe_params[:permissions] if safe_params[:permissions]

        if safe_params[:users].present?
          users = User.where(id: safe_params[:users].map(&:to_i))
          group.users << users
        end

        if group.save
          { message: "Group updated succesfully", group: group }
        else
          error!("Group not found", 404)
        end
      end

      desc "Updates group's permissions"
      params do
        # Managing
        optional :manage_users, type: Boolean, desc: "Can manage users"
        optional :manage_groups, type: Boolean, desc: "Can manage groups"
        optional :manage_inventory_categories, type: Boolean, desc: "Can inventory categories"
        optional :manage_inventory_items, type: Boolean, desc: "Can manage inventory items"
        optional :manage_reports_categories, type: Boolean, desc: "Can manage inventory categories"
        optional :manage_reports, type: Boolean, desc: "Can manage reports"
        optional :manage_users, type: Boolean, desc: "Can manage users"
        optional :manage_flows, type: Boolean, desc: "Can manage flows"
        optional :manage_inventory_formulas, type: Boolean, desc: "Can manage formulas"

        # Flows
        optional :flow_can_view_all_steps, type: Array,
                 desc: "Flow ids that can be viewed by the group"
        optional :flow_can_execute_all_steps, type: Array,
                 desc: "Flow ids that can be executed by the group"
        optional :flow_can_delete_own_cases, type: Array,
                 desc: "Flow ids that can be delete by the group"
        optional :flow_can_delete_all_cases, type: Array,
                 desc: "Flow ids that can be delete by the group"

        # Steps
        optional :can_view_step, type: Array,
                 desc: "Step ids that can be viewed by the group"
        optional :can_execute_step, type: Array,
                 desc: "Step ids that can be executed by the group"

        # Categories and sections
        optional :view_categories, type: Boolean, desc: "Can view inventory categories"
        optional :view_sections, type: Boolean, desc: "Can view sections"

        # Groups
        optional :groups_can_edit, type: Array,
                 desc: "Groups ids that can be edited by the group"
        optional :groups_can_view, type: Array,
                 desc: "Groups ids that can be viewed by the group"

        # Reports Categories
        optional :reports_categories_can_edit, type: Array,
                 desc: "Reports categories ids that can be edited by the group"
        optional :reports_categories_can_view, type: Array,
                 desc: "Reports categories ids that can be viewed by the group"

        # Inventory Categories
        optional :inventory_categories_can_edit, type: Array,
                 desc: "Inventory categories ids that can be edited by the group"
        optional :inventory_categories_can_view, type: Array,
                 desc: "Inventory sections ids that can be viewed by the group"

        # Inventory Sections
        optional :inventory_sections_can_view, type: Array,
                 desc: "Inventory sections ids that can be edited by the group"
        optional :inventory_sections_can_edit, type: Array,
                 desc: "Inventory sections ids that can be edited by the group"

        # Inventory Fields
        optional :inventory_fields_can_view, type: Array,
                 desc: "Inventory fields ids that can be edited by the group"
        optional :inventory_fields_can_edit, type: Array,
                 desc: "Inventory fields ids that can be edited by the group"
      end
      put ':id/permissions' do
        authenticate!
        group = Group.find(params[:id])
        validate_permission!(:edit, group)

        group_params = safe_params.permit(
          :manage_users,                :manage_inventory_categories,
          :manage_inventory_items,      :manage_groups,
          :manage_reports_categories,   :manage_reports,
          :manage_flows,                :view_categories,
          :manage_inventory_formulas,
          :view_sections,               :groups_can_edit => [],
          :inventory_sections_can_view => [], :inventory_sections_can_edit => [],
          :inventory_categories_can_view => [], :inventory_categories_can_edit => [],
          :inventory_fields_can_view => [], :inventory_fields_can_edit => [],
          :groups_can_view => [],             :reports_categories_can_edit => [],
          :reports_categories_can_view => [], :inventory_categories_can_edit => [],
          :reports_categories_can_view => [], :flow_can_view_all_steps => [],
          :flow_can_execute_all_steps => [], :flow_can_delete_own_cases => [],
          :step_view_all_case => [],          :step_execute_all_case => []
        )

        unless group_params.empty?
          group_params.each do |attr, value|
            # Remove this on Rails 4.1
            group.send("#{attr}=", value)
            group.permissions_will_change!
          end

          group.save!
        end

        { group: Group::Entity.represent(group) }
      end

      desc "Add user to group"
      params do
        requires :user_id, type: Integer, desc: "The user id you will add"
      end
      post ':id/users' do
        authenticate!

        group = Group.find(safe_params[:id])
        validate_permission!(:edit, group)
        group.users << User.find(safe_params[:user_id])
        group.save!

        { message: "User added successfully" }
      end

      desc "Removes user from group"
      params do
        requires :user_id, type: Integer, desc: "The user you will remove from group"
      end
      delete ':id/users' do
        authenticate!

        group = Group.find(safe_params[:id])
        validate_permission!(:edit, group)
        group.users.delete(User.find(safe_params[:user_id]))
        group.save!

        { message: "User added successfully" }
      end

      desc "List users from group"
      paginate per_page: 25
      get ':id/users' do
        authenticate!

        group = Group.find(safe_params[:id])
        validate_permission!(:view, group)

        {
          group: Group::Entity.represent(group),
          users: User::Entity.represent(
            paginate(group.users),
            display_type: 'full'
          )
        }
      end
    end
  end
end
