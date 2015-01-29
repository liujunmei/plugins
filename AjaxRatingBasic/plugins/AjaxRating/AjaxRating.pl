#########################################################
# Changes:
# 1.02 -- Fix for points="0" raters with MTAjaxRaterOnclickJS tag - thanks Arvind!
# 1.03 -- Added advanced use MTAjaxStarRaterAvergaeScoreWidth tag to output pixel width of current score
# 1.04 -- Added AjaxRatingAvgScore as alias for AjaxRatingAverageScore
# 1.05 -- Fix for Relative CGI Path in report comment email link
# 1.06 -- Fix listings with sort_order = "ascend"
# 1.1  -- MT4 Support
# 1.11 -- Bug fixes for tables not be installed and dynamic publishing issue with stars not showing
# 1.12 -- Bug fix for issue of settings not showing at the blog level in MT3.3x
# 1.13 -- Fix for warning about unitialized value in eq
# 1.14 -- Fix for tables not being installed on claen install on MT 4.01
# 1.15 -- New Pro feature - scheduled task for deleting recent votes on same object with same subnets (24.123.456)
# 1.16 -- Basic Fix only, update templates to include only basic features and tags

package MT::Plugin::AjaxRating;
use base qw(MT::Plugin);
use strict;

use MT;
use AjaxRating;

use vars qw($VERSION);
$VERSION = '1.16';
my $plugin = new MT::Plugin::AjaxRating({
	name => "AJAX Rating",
	description => "AJAX rating plugin for entries and comments and more.",
	doc_link => "http://mt-hacks.com/ajaxrating.html",
	plugin_link => "http://mt-hacks.com/ajaxrating.html",
	author_name => "Mark Carey",
	author_link => "http://mt-hacks.com/",
	object_classes => [ 'AjaxRating::Vote','AjaxRating::VoteSummary'],
	schema_version => "1.21",
	version => $VERSION,
    blog_config_template => \&AjaxRating::template,
    settings => new MT::PluginSettings([
        ['entry_mode', { Default => 0 }],
		['entry_max_points', { Default => 5 }],
		['comment_mode', { Default => 0 }],
		['comment_max_points', { Default => '5' }],
		['comment_threshold', { Default => 'all' }],
		['unit_width', { Default => 30 }],
		['rebuild', { Default => 0 }],
		['ratingl', { Default => 1 }],
		['hot_days', { Default => 7 }],
		['enable_delete_fraud', { Default => 0 }],
		['check_votes', { Default => 25 }],
    ]),
});
MT->add_plugin($plugin);

if (MT->version_number < 4.0) {
	require MT::Template::Context;
	MT::Template::Context->add_tag(AjaxRating => \&AjaxRating::ajax_rating);
	MT::Template::Context->add_tag(AjaxRatingAverageScore => \&AjaxRating::ajax_rating_avg_score);
	MT::Template::Context->add_tag(AjaxRatingAvgScore => \&AjaxRating::ajax_rating_avg_score);
	MT::Template::Context->add_tag(AjaxRatingTotalScore => \&AjaxRating::ajax_rating_total_score);
	MT::Template::Context->add_tag(AjaxRatingVoteCount => \&AjaxRating::ajax_rating_vote_count);

	MT::Template::Context->add_tag(AjaxRater => \&AjaxRating::rater);
	MT::Template::Context->add_tag(AjaxStarRater => \&AjaxRating::star_rater);
	MT::Template::Context->add_tag(AjaxThumbRater => \&AjaxRating::thumb_rater);
	MT::Template::Context->add_tag(AjaxRaterOnclickJS => \&AjaxRating::rater_onclick_js);

	MT::Template::Context->add_tag(AjaxRatingEntryMax => \&AjaxRating::entry_max);
	MT::Template::Context->add_tag(AjaxStarRaterWidth => \&AjaxRating::star_rater_width);
	MT::Template::Context->add_tag(AjaxStarRaterAverageScoreWidth => \&AjaxRating::star_rater_avg_score_width);
	MT::Template::Context->add_tag(AjaxStarUnitWidth => \&AjaxRating::star_unit_width);

	# Callbacks that remove VoteSummary records when objects get deleted
	MT::Entry->add_callback('pre_remove', 5, $plugin, \&AjaxRating::entry_delete_handler);
	MT::Blog->add_callback('pre_remove', 5, $plugin, \&AjaxRating::blog_delete_handler);

	# Callbacks that change the obj_type column when objects are published or unpublished
	MT::Entry->add_callback('post_save', 5, $plugin, \&AjaxRating::entry_post_save);
}

sub instance {
	return $plugin;
}

sub init_app {
	my $plugin = shift;
	my ($app) = @_;
	return unless $app->isa('MT::App::CMS');
    $app->add_methods(
        ajaxrating_install_templates => sub { AjaxRating::install_templates($plugin, @_); },
    );
}

## init_registry used only by MT4+ ##

sub init_registry {
	my $component = shift;
	my $reg = {
		'applications' => {
			'cms' => {
				'methods' => {
					'ajaxrating_install_templates' => sub { AjaxRating::install_templates($plugin, @_); },
				}
			}
		},
        object_types => {
           'ajaxrating_vote' => 'AjaxRating::Vote',
           'ajaxrating_votesummary'	=> 'AjaxRating::VoteSummary',
        },
		'callbacks' => {
			'MT::Entry::pre_remove' => \&AjaxRating::entry_delete_handler,
			'MT::Blog::pre_remove' => \&AjaxRating::blog_delete_handler,
			'MT::Entry::post_save' => \&AjaxRating::entry_post_save,
		},
		tags => {
			function => {
        	   AjaxRating => \&AjaxRating::ajax_rating,
        	   AjaxRatingAverageScore => \&AjaxRating::ajax_rating_avg_score,
        	   AjaxRatingAvgScore => \&AjaxRating::ajax_rating_avg_score,
        	   AjaxRatingTotalScore => \&AjaxRating::ajax_rating_total_score,
        	   AjaxRatingVoteCount => \&AjaxRating::ajax_rating_vote_count,
        	   AjaxRater => \&AjaxRating::rater,
        	   AjaxStarRater => \&AjaxRating::star_rater,
        	   AjaxThumbRater => \&AjaxRating::thumb_rater,
        	   AjaxRaterOnclickJS => \&AjaxRating::rater_onclick_js,
        	   AjaxRatingEntryMax => \&AjaxRating::entry_max,
			   AjaxStarRaterWidth => \&AjaxRating::star_rater_width,
			   AjaxStarRaterAverageScoreWidth => \&AjaxRating::star_rater_avg_score_width,
			   AjaxStarUnitWidth => \&AjaxRating::star_unit_width,
			},
		},
	};
	$component->registry($reg);
}


1;
