# coding: utf-8

class GamificationController < ApplicationController
  unloadable

  menu_item :project_gamification

  before_filter :woj_auth_gamification, :except => :error

  before_filter :auth_gamification, only: [:index, :project]
  before_filter :find_project, only: [:project]

  def index
    if params[:id]
      user_id = params[:id]
    else
      user_id = User.current.id
    end
    @user = Gamification.find_by_user_id(user_id)
    if !@user
      @user = Gamification.find_by_user_id(User.current.id)
    end
    
    @medal_types = GamificationMedalType.all
    @medals = @user.gamification_medal_assignment
    
    @medal_count = {}
    GamificationMedalType.all.each do |medal|
      @medal_count[medal.name] = 0
    end
    @medals.each do |medal|
      @medal_count[medal.gamification_medal_type.name] += 1
    end
  end

  def upload_image
    user = Gamification.find_by_user_id(User.current.id)
    user.image = params[:gamification][:image].read
    if user.save
      flash[:notice] = l(:image_uploaded) 
      redirect_to action: 'index'
    end
  end

  def remove_image
    user = Gamification.find_by_user_id(User.current.id)
    user.image = nil
    if user.save
      redirect_to action: 'index'
    end
  end

  def project
    current_user_id = User.current.id
    project_id = Project.find_by_identifier(params[:project_id]).id

    # Determine if project exists and if they're already members,
    # else register for project
    if Member.exists?({project_id: project_id, user_id: current_user_id}) && 
       !GamificationProject.exists?({project_id: project_id, user_id: current_user_id})
      project = GamificationProject.new
      project.user_id = current_user_id
      project.project_id = project_id
      project.save
    end

    unless GamificationProject.exists?({user_id: current_user_id, project_id: project_id})
      flash[:error] = l(:not_project_member) 
      redirect_to action: 'error'
      return
    end

    @project_users = GamificationProject.where({project_id: project_id})
    @current_user_id = current_user_id
  end

  def entry
  end

  def create
    current_user_id = User.current.id

    # user create
    user = Gamification.new
    user.user_id = current_user_id

    # user project create
    members = Member.where(user_id: current_user_id).select('project_id')
    members.each do |member|
      project = GamificationProject.new
      project.user_id = current_user_id
      project.project_id = member.project_id
      project.save
    end

    # badge table create
    user_badge = GamificationBadge.new({user_id: current_user_id})
    unless user_badge.save
      redirect_to action: 'error'
    end

    unless user.save
      redirect_to action: 'error'
    else
      flash[:notice] = l(:registration_complete)
      redirect_to action: 'index'
    end
  end

  def tutorial
  end

  def badges
    @user = Gamification.find_by_user_id(User.current.id)
    @user_badges = GamificationBadge.find_by_user_id(@user.user_id)
  end

  def rating
    my_account = Gamification.find_by_user_id(User.current.id)
    medals = GamificationMedalType.all
    @medals = {}
    GamificationMedalType.all.each do |medal|
      @medals[medal.name] = medal.id
    end
    users = Gamification.all
    @users = {}
    users.each do |user|
      @users[user.user.login] = user.user_id unless user.user_id == my_account.user_id
    end
  end

  # ajax 
  def search
    @user = Gamification.find_by_user_id(params[:rate_user].to_i)
  end

  def regist_rating
    assignment = GamificationMedalAssignment.new
    assignment.medal_id = params[:medal]
    assignment.user_orig_id = User.current.id
    assignment.user_assign_id = params[:rate_user].to_i
    if assignment.save
      flash[:notice] = l(:voted)
      redirect_to action: 'rating'
    end
  end

  def ranking
    @users = Gamification.order("point DESC") #.limit(10) # removing limit until pagination is done
  end

  def destroy
    current_user_id = User.current.id
    user = Gamification.find_by_user_id(current_user_id)
    user_badge = GamificationBadge.find_by_user_id(current_user_id)

    if user.destroy && user_badge.destroy && GamificationProject.destroy_all({user_id: current_user_id})
      flash[:notice] = l(:removed)
      redirect_to action: 'entry'
    else
      redirect_to action: 'error'
    end
  end

  def error
  end

  private
  def find_project
    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

#  Admin = 1
#  Anonymous = 2

  def auth_gamification
    user_id = User.current.id

    # Error if guest or administrator
    # This is not really working, will look into it again
#    if user_id == Anonymous
#      flash[:error] = l(:cannot_use)
#      redirect_to action: 'error'
#      return 
#    end

    unless Gamification.exists?(user_id: user_id)
      redirect_to action: 'entry'
      return
    end 
  end

  def woj_auth_gamification
    if !User.current.allowed_to?({:controller => 'gamification', :action => 'index'}, nil, {:global => true})
      flash[:error] = l(:cannot_use)
      redirect_to action: 'error'
      return 
    end
  end

end
