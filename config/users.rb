# This file defines the users associated with your project, it is basically the
# mailing list for release notes.
# This module must define a method named "users" which returns an array of user
# objects.
# You can split your users into "admin" and "user" groups, the main difference
# between the two is that admin users will get all tag emails, users will get
# emails on external/official releases only.
# Users are also prohibited from running the tag_project script, but this is
# really just to prevent a casual user from executing it inadvertently and it is
# not intended to be a serious security gate.
module Origen
  module Users
    def users
      @users ||= [
        # Admins
        User.new('Stephen McGinty', 'r49409', :admin),
        User.new('Thao Huynh', 'r6aanf', :admin),
        User.new('Daniel Hadad', 'ra6854', :admin),
        User.new('Mike Bertram', 'rgpj20', :admin),
        User.new('Ronnie Lajaunie', 'b01784', :admin),
        User.new('Priyavadan Kumar', 'b21094', :admin),
        User.new('Wendy Malloch', 'ttz231', :admin),
        User.new('Chris Hume', 'r20984', :admin),
        User.new('Chris Nappi', 'ra5809', :admin),
        User.new('Rabin Shahav', 'r53653', :admin),
        User.new('Melody Caron', 'b45830', :admin),
        User.new('Milind Parab', 'b46434', :admin),
        User.new('Aaron Burgmeier', 'ra4905', :admin),
        User.new('b07507', :admin),  # Brian C
        User.new('r28728', :admin),  # Stephen T
        User.new('Will Forfang', 'b49009', :admin),
        User.new('b49434', :admin),  # Tyler D
        User.new('Jayson Vogler', 'ra6523', :admin),
        User.new('Corey Engelken', 'b50956', :admin),
        User.new('Ken Reed', 'rvkl80', :admin),
        User.new('Jiang Liu', 'b20251', :admin),
        User.new('David Welguisz', 'r7aajf', :admin),
        # Users
        User.new('Origen Users', 'origen'),  # The rGen mailing list
        User.new('MCD Modularity', 'mcdmods'),
        User.new('Test Community', 'testcop3')
      ]
    end
  end
end
