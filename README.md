# mofa
a lightweight remote chef-solo runner

Before you can start using mofa please create a config file:

    mkdir ~/.mofa

    cat <<EOF > ~/.mofa/config.yaml
    # global mofa settings

    # Admin User Account that should be used for all mofa tasks.
    # The user has to be able to login passwordless
    # and has tohave passwordless sudo permissions.
    ssh_user: vagrant
    ssh_port: 2222
    ssh_keyfile: ~/.ssh/id_rsa_vagrant_insecure

    # A REST-Webservice that returns a list of hosts that are potentially
    # manageable with this mofa.
    #service_hostlist_url: http://a-real-server:9292/hosts
    # You can also have a json-file somewhere. See the test-file in the rspec-folder
    service_hostlist_url: file:///Users/<yourname>/.mofa/example_hostlist.json
    service_hostlist_default_filter: "localhost"
    service_hostlist_api_key: <a api key used to access the above service>

    # where to build tmporary cookbook packages and so on
    tmp_dir: /var/tmp

    # The cookbook architectural pattern should becodified by following
    # a cookbook naming schema:
    # * Cookbooks beginning with "env_*" are Envrionment Cookbooks
    # * Cookbooks haven a prefix like "<organisation_name>_*" are
    #   so-called Wrapper Cookbooks
    # * Cookbooks having a "base_" Prefix are Base Cookbooks

    cookbook_type_indicator:
      env: "^env_.*"
      wrapper: "^(<your_org>_|<another_pattern>_).*"
      base: ".*_base$"

    # Binrepo for released cookbooks
    binrepo_base_url: http://binrepo-server/cookbooks/

    # Releasing into binrepo
    binrepo_host: localhost
    binrepo_ssh_user: berkshelf
    binrepo_ssh_port: 2222
    binrepo_ssh_keyfile: ~/.ssh/id_rsa_vagrant_insecure
    binrepo_import_dir: /var/berks-api-binrepo/cookbooks

    EOF

# local Development

    $ git clone https://github.com/pingworks/mofa.git
    $ cd mofa
    $ bundle install
    $ cd ../somewhere_chef-env_some_cookbook
    $ export BUNDLE_GEMFILE=../mofa/Gemfile
    $ bundle exec
    $ ../mofa/bin/mofa provision .
