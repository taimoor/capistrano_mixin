unless Capistrano::Configuration.respond_to?(:instance)
	abort "capistrano/ext/multistage requires Capistrano 2"
end

if  Capistrano::Configuration.instance
	Capistrano::Configuration.instance.load do
		set :user, "deploy"
		set :use_sudo, true
		set :shell, '/bin/bash --login'
		set :deploy_to, "/home/deploy/apps/#{fetch(:application)}"
		set :deploy_via, :remote_cache

		set :bluepill_bin, 'bluepill'

		default_run_options[:pty] = true
		default_run_options[:shell] = '/bin/bash --login'
		ssh_options[:forward_agent] = true

		after "deploy:finalize_update", "db:symlink"
		after "deploy:finalize_update", "faye_token:symlink"
		after "deploy:finalize_update", "sockets:symlink"
		after "deploy:finalize_update", "uploads:symlink"
		after 'deploy:finalize_update', 'faye:restart'

	    namespace :uploads do
	      task :symlink do
	        run "rm -rf #{release_path}/public/uploads"
	        run "ln -nfs #{shared_path}/uploads #{release_path}/public/uploads"
	      end
	    end

		namespace :db do
			task :symlink do
				run "rm -f #{release_path}/config/database.yml && ln -nfs #{shared_path}/config/database.yml #{release_path}/config/database.yml"
			end
		end
		namespace :faye_token do
			task :symlink do
				run "ln -nfs #{shared_path}/config/faye_token.rb #{release_path}/config/initializers/faye_token.rb"
			end
		end

		namespace :sockets do
			task :symlink do
				run "ln -nfs #{shared_path}/sockets #{release_path}/tmp/sockets"
			end
		end

		namespace :deploy do
			desc "Start bluepill daemon"
			task :start do
				run "sudo #{bluepill_bin} load /etc/bluepill/#{application}.pill"
			end
			desc "Stop bluepill daemon"
			task :stop do
				run "sudo #{bluepill_bin} #{application} stop"
			end
			desc "Restart bluepill daemon"
			task :restart, :roles => :app, :except => { :no_release => true } do
				run "sudo #{bluepill_bin} #{application} restart"
			end
			desc "Show status of the bluepill daemon"
			task :status do
				run "sudo #{bluepill_bin} #{application} status"
			end
		end

		namespace :faye do
			desc "Restart Faye"
			task :restart do
				run "sudo kill -9 $(lsof -i :9292 -t)"
				run "cd #{current_path} && bundle exec rackup faye.ru -s puma -E production -D"
			end
		end

	end
end
