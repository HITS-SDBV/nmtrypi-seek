[![Build Status](https://travis-ci.org/HITS-SDBV/nmtrypi-seek.svg?branch=master)](https://travis-ci.org/HITS-SDBV/nmtrypi-seek)

# SEEK

## License

Copyright (c) 2009-2014, University of Manchester and HITS gGmbH

[BSD 3-clause](BSD-LICENSE)

## About SEEK

The SEEK platform is a web-based resource for sharing heterogeneous scientific research datasets,models or simulations, processes and research outcomes. It preserves associations between them, along with information about the people and organisations involved.
Underpinning SEEK is the ISA infrastructure, a standard format for describing how individual experiments are aggregated into wider studies and investigations. Within SEEK, ISA has been extended and is configurable to allow the structure to be used outside of Biology.
SEEK is incorporating semantic technology allowing sophisticated queries over the data, yet without getting in the way of your users.

For an example of SEEK please visit our [Demo](http://demo.euro-seek.org).

To see SEEK being used for real science, as part of [SysMO](http://sysmo.net) please visit [SysMO SEEK](http://seek.sysmo-db.org)

For more information please visit: [SEEK for Science](http://www.seek4science.org/)

## FAIRDOM

SEEK is being developed and funded as part of the FAIRDOM initiative.
For more information please visit: [FAIRDOM](http://fair-dom.org).


## Installation

We recommend installing SEEK on Debian or Ubuntu.

To install the latest release please visit:
[SEEK install guide](http://seek4science.org/sites/default/files/seekdocs/doc/INSTALL.html)

For details about other distributions and installing on Mac OS X please visit:
[Other distributions guide](http://seek4science.org/sites/default/files/seekdocs/doc/OTHER-DISTRIBUTIONS.html)

The latest versions of these documents are also [included](doc).

## development environment with vagrant

You can use the provided vagrant environment to develop in the project:
<pre>
git submodule update --init --recursive
cd vagrant
vagrant --extra-vars-file=../ansible_vars.yml --ansible-playbook=../ansible_site.yml --vmname=seek --cpus=2 --memory=4096 --nfs up
vagrant ssh
</pre>

If the provision process appears to be hanging (e.g. does not make progress) you can temrinate the process (Ctrl+C) and provision again:
<pre>
vagrant halt
vagrant --extra-vars-file=../ansible_vars.yml --ansible-playbook=../ansible_site.yml --vmname=seek --cpus=2 --memory=4096 --nfs up --provision
</pre>
This will restart the provisioning process - and ansible will take care of finishing unfinished steps.

<pre>
vagrant ssh
</pre>
You are in the virtual machine and you can find this project mounted in /project
You can start eclipse with
<pre>
cd /project # this is important to set the proper ruby version and GEM_HOME
~/sw/eclipse/4.5/eclipse/eclipse
</pre>

To shutdown (after logout) and resume use:
<pre>
vagrant halt
vagrant --vmname=seek --cpus=2 --memory=4096 --nfs up
</pre>

With every git pull, it might be necessary to update the submodule also; git status should show if it is necessary
also, since the roles might be installed from ansible-galaxy in new versions, the 'old' ones need to be removed
ansible-galaxy does not have a lock feature with versions yet
<pre>
git submodule update
rm -r -- vagrant/ansible/roles/*/
</pre>

## Contacting Us

For details about how to contact us, to raise bugs or offer suggestion, please visit [Contacting Us](http://seek4science.org/contact)


## Credit

SEEK is developed using the [RubyMine IDE](http://www.jetbrains.com/ruby/), for which we are provided a free open source license by JetBrains.

![JetBrains](http://seek4science.org/sites/default/files/logo_jetbrains_smaller.gif)

Please check our [CREDITS file](doc/CREDITS) for additional credits and acknowledgements


[![Build Status](https://travis-ci.org/seek4science/seek.svg?branch=master)](https://travis-ci.org/seek4science/seek)

