# encoding: utf-8

#  Copyright (c) 2022, Pfadibewegung Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

require 'spec_helper'

describe Person::UserPasswordOverrideMailer do

  let(:sender) { people(:top_leader) }
  let(:recipient) { people(:bottom_member) }
  let(:mail) { Person::UserPasswordOverrideMailer.send_mail(recipient, sender.full_name) }

  subject { mail }

  #TODO not working
  its(:to)       { should == [recipient.email] }
  its(:sender)   { should == [sender.email] }
  its(:subject)  { should =~ 'Login für' }
  its(:body)     { should =~ /Hallo #{person.first_name}/ }

end
