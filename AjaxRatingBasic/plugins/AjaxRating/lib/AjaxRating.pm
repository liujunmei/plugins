#########################################################

package AjaxRating;
use strict;

use MT;
use MT::Plugin;
use AjaxRating::Vote;
use AjaxRating::VoteSummary;

sub ajax_rating {
	my $ctx = shift;
	my $args = shift;

	my $obj_type = $args->{type};
	if (!$obj_type) {
		if ($ctx->stash('comment')) {
			$obj_type = 'comment';
		} else {
			$obj_type = 'entry';
		}
	}
	if ($obj_type eq 'trackback') { $obj_type = 'ping'; }
	my $obj = $ctx->stash($obj_type);
	my $obj_id = $obj->id if $obj;
	if ($args->{id}) { $obj_id = $args->{id}; }

	my $votesummary = AjaxRating::VoteSummary->load({ obj_type => $obj_type, obj_id => $obj_id });
	if ($votesummary) {
		my $show = defined($args->{show}) ? $args->{show} : 'total_score';
		if ($show eq 'avg_score') {
			return ($votesummary->avg_score);
		} elsif ($show eq 'vote_count') {
			return ($votesummary->vote_count);
		} else {
			return ($votesummary->total_score);
		}
	} else {
		return 0;
	}
}

sub ajax_rating_avg_score {
	my $ctx = shift;
	my $args = shift;
	$args->{show} = 'avg_score';
	ajax_rating($ctx, $args);
}

sub ajax_rating_vote_count {
	my $ctx = shift;
	my $args = shift;
	$args->{show} = 'vote_count';
	ajax_rating($ctx, $args);
}

sub ajax_rating_total_score {
	my $ctx = shift;
	my $args = shift;
	ajax_rating($ctx, $args);
}


sub rater {
	my $ctx = shift;
	my $args = shift;
	my $rater_type = $args->{rater_type} || 'star';
	my $blog = $ctx->stash('blog');

	my $obj_type = $args->{type};
	if (!$obj_type) {
		if ($ctx->stash('comment')) {
			$obj_type = 'comment';
		} else {
			$obj_type = 'entry';
		}
	}

	if ($obj_type eq 'trackback') { $obj_type = 'ping'; }
	my $obj = $ctx->stash($obj_type);
		#	or return $ctx->error("Unknown object type");
	my $obj_id = $obj->id if $obj;
	my $blog_id = $blog->id;
	if ($args->{id}) { $obj_id = $args->{id}; }

	my $author_id = 0;
	if ($obj_type eq 'comment') {
		$author_id = $obj->commenter_id || 0;
	} elsif ($obj_type eq 'entry') {
		$author_id = $obj->author_id;
	}

	my $avg_score = 0;
	my $total_score = 0;
	my $vote_count = 0;
	my $votesummary = AjaxRating::VoteSummary->load({ obj_type => $obj_type, obj_id => $obj_id });	
	if ($votesummary) {
		$avg_score = $votesummary->avg_score;
		$vote_count = $votesummary->vote_count;
		$total_score = $votesummary->total_score;
	}

	my $html;

	if ($rater_type eq 'star') {
		my $plugin = MT::Plugin::AjaxRating->instance;
		my $config = $plugin->get_config_hash('blog:'.$blog->id);
		my $unit_width = $config->{unit_width};
		my $max_setting = $obj_type . '_max_points';
		my $units = $config->{$max_setting} || $args->{max_points} || 5;
		my $rater_length = ($units * $unit_width);
		my $star_width = (sprintf("%.1f",$avg_score / $units * $rater_length)) . "px";
		$rater_length .= 'px';
		my $ratingl = '';
		if ($config->{ratingl}) { $ratingl = "		<!-- AJAX Rating powered by MT Hacks http://mt-hacks.com/ajaxrating.html -->"; }
		$html = <<HTML;
<div id="rater$obj_type$obj_id">
			<ul id="rater_ul$obj_type$obj_id" class="unit-rating" style="width:$rater_length;">
		<li class="current-rating" id="rater_li$obj_type$obj_id" style="width:$star_width;">Currently $avg_score/$units</li>
HTML
		for(my $star=1;$star<=$units;$star++) {
			$html .= <<HTML;
		<li><a href="#" title="$star out of $units" class="r$star-unit rater" onclick="pushRating('$obj_type',$obj_id,$star,$blog_id,$total_score,$vote_count,$author_id); return(false);">$star</a></li>
HTML
		}
		$html .= <<HTML;
		</ul> $ratingl
<span class="thanks" id="thanks$obj_type$obj_id"></span>
</div>
HTML
	} elsif ($rater_type eq 'onclick_js') {
		my $points = defined ($args->{points}) ? $args->{points} : 1;
		$html = <<HTML; 
pushRating('$obj_type',$obj_id,$points,$blog_id,$total_score,$vote_count,$author_id); return(false);
HTML
	} else {
		my $static_path = MT->instance->static_path . "plugins/AjaxRating/images";
		my $report_icon = '';
		if ($args->{report_icon}) { 
			$report_icon = <<HTML;
			<a href="#" title="Report this comment" onclick="reportComment($obj_id); return(false);"><img src="$static_path/report.gif" alt="Report this comment" /></a>
HTML
		}
		$html = <<HTML;
<span id="thumb$obj_type$obj_id">
<a href="#" title="Vote up" onclick="pushRating('$obj_type',$obj_id,1,$blog_id,$total_score,$vote_count,$author_id); return(false);"><img src="$static_path/up.gif" alt="Vote up" /></a> <a href="#" title="Vote down" onclick="pushRating('$obj_type',$obj_id,-1,$blog_id,$total_score,$vote_count,$author_id); return(false);"><img src="$static_path/down.gif" alt="Vote down" /></a> $report_icon
</span><span class="thanks" id="thanks$obj_type$obj_id"></span>
HTML
	}
	return $html;
}

sub star_rater {
	my $ctx = shift;
	my $args = shift;
	$args->{rater_type} = 'star';
	rater($ctx, $args);
}

sub thumb_rater {
	my $ctx = shift;
	my $args = shift;
	$args->{rater_type} = 'thumb';
	rater($ctx, $args);
}

sub rater_onclick_js {
	my $ctx = shift;
	my $args = shift;
	$args->{rater_type} = 'onclick_js';
	rater($ctx, $args);
}

sub entry_max {
	my $ctx = shift;
	my $args = shift;
	my $blog = $ctx->stash('blog');
	my $plugin = MT::Plugin::AjaxRating->instance;
	my $config = $plugin->get_config_hash('blog:'.$blog->id);
	$config->{entry_max_points};
}

sub star_rater_width {
	my $ctx = shift;
	my $args = shift;
	my $blog = $ctx->stash('blog');
	my $plugin = MT::Plugin::AjaxRating->instance;
	my $config = $plugin->get_config_hash('blog:'.$blog->id);
	my $obj_type = $args->{type} || 'entry';
	my $max_setting = $obj_type . '_max_points';
	my $rater_width = $config->{$max_setting} * $config->{unit_width};
}

sub star_rater_avg_score_width {
	my $ctx = shift;
	my $args = shift;
	my $blog = $ctx->stash('blog');
	my $plugin = MT::Plugin::AjaxRating->instance;
	my $config = $plugin->get_config_hash('blog:'.$blog->id);
	my $total_width = star_rater_width($ctx,$args);
	my $avg_score = ajax_rating_avg_score($ctx,$args);
	my $obj_type = $args->{type} || 'entry';
	my $max_setting = $obj_type . '_max_points';
	my $avg_score_width = ($avg_score / $config->{$max_setting}) * $total_width;
}

sub star_unit_width {
	my $ctx = shift;
	my $args = shift;
	my $blog = $ctx->stash('blog');
	my $plugin = MT::Plugin::AjaxRating->instance;
	my $config = $plugin->get_config_hash('blog:'.$blog->id);
	my $unit_width = $config->{unit_width};
	if ($args->{mult_by}) { $unit_width = $unit_width * $args->{mult_by}; }
	return $unit_width;
}

sub entry_delete_handler {
    my ($cb, $object) = @_;
	my $obj_type = 'entry';
    my $votesummary = AjaxRating::VoteSummary->load({ 'obj_id' => $object->id, 'obj_type' => $obj_type });
  # $votesummary->purge() if $votesummary;
	$votesummary->remove if $votesummary;
}

sub blog_delete_handler {
    my ($cb, $object) = @_;
	my $obj_type = 'blog';
    my $votesummary = AjaxRating::VoteSummary->load({ 'obj_id' => $object->id, 'obj_type' => $obj_type });
  # $votesummary->purge() if $votesummary;
	$votesummary->remove if $votesummary;
}

sub entry_post_save {
	my ($cb, $entry) = @_;
	my $votesummary;
	if ($entry->status != 2) {
		if ($votesummary = AjaxRating::VoteSummary->load({ obj_type => 'entry', obj_id => $entry->id })) {
			$votesummary->obj_type('entry0');
			$votesummary->save;
		}
	} else {
		if ($votesummary = AjaxRating::VoteSummary->load({ obj_type => 'entry0', obj_id => $entry->id })) {
			$votesummary->obj_type('entry');
			$votesummary->save;
		}
	}
}

sub install_templates {
	my $plugin = shift;
	my ($app) = @_;
	my $q = $app->{query};
	my $blog_id = $app->{query}->param('blog_id');
    my $param = { };

	my $perms = $app->{perms};
    return $app->error("Insufficient permissions for modifying templates for this weblog.")
        unless $perms->can_edit_templates() || $perms->can_administer_blog ||
               $app->{author}->is_superuser();

	require MT::Template;

	my $templates = [
 	         {
               'outfile' => 'ajaxrating.js',
 	           'name' => 'Ajax Rating Javascript',
 	           'type' => 'index',
   	         'rebuild_me' => '0'
    	      },
 	         {
               'outfile' => 'ajaxrating.css',
 	           'name' => 'Ajax Rating Styles',
 	           'type' => 'index',
   	         'rebuild_me' => '0'
    	      },
 	         {
 	           'name' => 'Widget: Ajax Rating',
 	           'type' => 'custom',
   	         'rebuild_me' => '0'
    	      },
    	    ];

	use MT::Util qw(dirify);

	require MT;
	use File::Spec;
	my $path = 'plugins/AjaxRating/tmpl';
	local (*FIN, $/);
	$/ = undef;
	my $data;
	foreach my $tmpl (@$templates) {
    	my $file = File::Spec->catfile($path, dirify($tmpl->{name}).'.tmpl');
 	   if ((-e $file) && (-r $file)) {
  	      open FIN, "<$file"; $data = <FIN>; close FIN;
  	      $tmpl->{text} = $data;
  	  }
	}

	my $tmpl_list = $templates;
	my $tmpl;

    foreach my $val (@$tmpl_list) {
            $val->{name} = $app->translate($val->{name});
            $val->{text} = $app->translate_templatized($val->{text});

        my $terms = {};
        $terms->{blog_id} = $blog_id;
        $terms->{type} = $val->{type};
    	$terms->{name} = $val->{name};
            
        $tmpl = MT::Template->load($terms);

        if ($tmpl) {
			return $app->error("Template already exists. To reinstall the default template, first delete or rename the existing template.': " . $tmpl->errstr);
		} else {
			$tmpl = new MT::Template;
   	 		$tmpl->build_dynamic(0);
   			$tmpl->set_values($val);
   			$tmpl->blog_id($blog_id);
    		$tmpl->save or return $app->error("Error creating new template: " . $tmpl->errstr);
			$app->rebuild_indexes( BlogID => $blog_id, Template => $tmpl, Force => 1 );
		}
	}
	$app->redirect($app->uri('mode' => 'cfg_plugins', args => { 'blog_id' => $blog_id } ));
}

sub template {
	my ($plugin, $param) = @_;
	my $app = MT->instance;
	my $blog_id = $app->{query}->param('blog_id');
	my $tmpl;
	if (MT->version_number < 4.0) {
    		$tmpl = <<MT33;
<p>
AJAX Rating enables visitors to rate items such as entries and comments.
</p>

<div class="setting">
		<div class="label"><label for="templates">Install Templates</label></div>
		<div class="field">
		<p><a href="<TMPL_VAR NAME=SCRIPT_URL>?__mode=ajaxrating_install_templates&blog_id=$blog_id">Click here to install the Ajax Rating templates for this blog</a>.</p><br />
		</div>

		<div class="label"><label for="entry_mode">Entry Mode</label></div>
		<div class="field">
			<select name="entry_mode">
				<option value="0"<TMPL_IF NAME=ENTRY_MODE_0> selected="selected"</TMPL_IF>>Off</option>
				<option value="1"<TMPL_IF NAME=ENTRY_MODE_1> selected="selected"</TMPL_IF>>Thumbs Up/Down</option>
				<option value="2"<TMPL_IF NAME=ENTRY_MODE_2> selected="selected"</TMPL_IF>>Star/Point Rating</option>
			</select>
			<p>Choose the mode to use for rating entries.</p><br />
		</div>

		<div class="label"><label for="entry_max_points">Entry Max Points</label></div>
		<div class="field">
			<select name="entry_max_points">
				<option value="1"<TMPL_IF NAME=ENTRY_MAX_POINTS_1> selected="selected"</TMPL_IF>>1</option>
				<option value="2"<TMPL_IF NAME=ENTRY_MAX_POINTS_2> selected="selected"</TMPL_IF>>2</option>
				<option value="3"<TMPL_IF NAME=ENTRY_MAX_POINTS_3> selected="selected"</TMPL_IF>>3</option>
				<option value="4"<TMPL_IF NAME=ENTRY_MAX_POINTS_4> selected="selected"</TMPL_IF>>4</option>
				<option value="5"<TMPL_IF NAME=ENTRY_MAX_POINTS_5> selected="selected"</TMPL_IF>>5</option>
				<option value="6"<TMPL_IF NAME=ENTRY_MAX_POINTS_6> selected="selected"</TMPL_IF>>6</option>
				<option value="7"<TMPL_IF NAME=ENTRY_MAX_POINTS_7> selected="selected"</TMPL_IF>>7</option>
				<option value="8"<TMPL_IF NAME=ENTRY_MAX_POINTS_8> selected="selected"</TMPL_IF>>8</option>
				<option value="9"<TMPL_IF NAME=ENTRY_MAX_POINTS_9> selected="selected"</TMPL_IF>>9</option>
				<option value="10"<TMPL_IF NAME=ENTRY_MAX_POINTS_10> selected="selected"</TMPL_IF>>10</option>
			</select>
			<p>Choose the maximum number of points or stars when rating entries.</p><br />
		</div>
<TMPL_IF NAME=RATINGL_0>
		<div class="label"><label for="comment_mode">Comment Mode</label></div>
		<div class="field">
			<select name="comment_mode">
				<option value="0"<TMPL_IF NAME=COMMENT_MODE_0> selected="selected"</TMPL_IF>>Off</option>
				<option value="1"<TMPL_IF NAME=COMMENT_MODE_1> selected="selected"</TMPL_IF>>Thumbs Up/Down</option>
				<option value="2"<TMPL_IF NAME=COMMENT_MODE_2> selected="selected"</TMPL_IF>>Star/Point Rating</option>
			</select>
			<p>Choose the mode to use for rating comments.</p><br />
		</div>

		<div class="label"><label for="comment_max_points">Comment Max Points</label></div>
		<div class="field">
			<select name="comment_max_points">
				<option value="1"<TMPL_IF NAME=COMMENT_MAX_POINTS_1> selected="selected"</TMPL_IF>>1</option>
				<option value="2"<TMPL_IF NAME=COMMENT_MAX_POINTS_2> selected="selected"</TMPL_IF>>2</option>
				<option value="3"<TMPL_IF NAME=COMMENT_MAX_POINTS_3> selected="selected"</TMPL_IF>>3</option>
				<option value="4"<TMPL_IF NAME=COMMENT_MAX_POINTS_4> selected="selected"</TMPL_IF>>4</option>
				<option value="5"<TMPL_IF NAME=COMMENT_MAX_POINTS_5> selected="selected"</TMPL_IF>>5</option>
				<option value="6"<TMPL_IF NAME=COMMENT_MAX_POINTS_6> selected="selected"</TMPL_IF>>6</option>
				<option value="7"<TMPL_IF NAME=COMMENT_MAX_POINTS_7> selected="selected"</TMPL_IF>>7</option>
				<option value="8"<TMPL_IF NAME=COMMENT_MAX_POINTS_8> selected="selected"</TMPL_IF>>8</option>
				<option value="9"<TMPL_IF NAME=COMMENT_MAX_POINTS_9> selected="selected"</TMPL_IF>>9</option>
				<option value="10"<TMPL_IF NAME=COMMENT_MAX_POINTS_10> selected="selected"</TMPL_IF>>10</option>
			</select>
			<p>Choose the maximum number of points or stars when rating entries.</p><br />
		</div>

		<div class="label"><label for="comment_threshold">Default Comment Threshold</label></div>
		<div class="field">
			<input name="comment_threshold" type="text" size="3" value="<TMPL_VAR NAME=COMMENT_THRESHOLD>"></input>&nbsp;
			<p>Advanced feature: choose the default rating or total score threshold for comments to be displayed.</p><br />
		</div>
</TMPL_IF>
		<div class="label"><label for="unit_width">Star Icon Width</label></div>
		<div class="field">
			<input name="unit_width" type="text" value="<TMPL_VAR NAME=UNIT_WIDTH>"></input>&nbsp;
			<p>Advanced feature: choose the width of the star icon. Default is 30.</p><br />
		</div>
		<div class="label"><label for="rebuild">Rebuild After a Vote</label></div>
		<div class="field">
			<select name="rebuild">
				<option value="0"<TMPL_IF NAME=REBUILD_0> selected="selected"</TMPL_IF>>No Rebuilds</option>
				<option value="1"<TMPL_IF NAME=REBUILD_1> selected="selected"</TMPL_IF>>Rebuild Entry Only</option>
				<option value="2"<TMPL_IF NAME=REBUILD_2> selected="selected"</TMPL_IF>>Rebuild Entry, Archives, Indexes</option>
				<option value="3"<TMPL_IF NAME=REBUILD_3> selected="selected"</TMPL_IF>>Rebuild Indexes Only</option>
			</select>
			<p>Choose an option to rebuild pages after a vote is registered. You should only rebuild those pages where you are displaying ratings. WARNING: Rebuilding can affect performance on high-traffic sites with a lot of active voting.</p><br />
		</div>
		<input name="ratingl" type="hidden" value="<TMPL_VAR NAME=RATINGL>"></input>

</div>
MT33
	} else {
		rebuild_ar_templates($app);
		$tmpl = <<MT40;
<mtapp:setting
    id="install_ajaxrating_templates"
    label="<__trans phrase="Install Ajax Rating Templates">"
    hint=""
	class="actions-bar"
    show_hint="0">

    <div class="actions-bar-inner pkg actions">
        <a href="javascript:void(0)" onclick="return openDialog(false, 'install_blog_templates','template_path=plugins/AjaxRating/default_templates&amp;set=ajax_rating_templates&amp;blog_id=$blog_id&amp;return_args=__mode%3Dcfg_plugins%26%26blog_id%3D$blog_id')" class="primary-button"><__trans phrase="Install Templates"></a>
	</div>

</mtapp:setting>		

<mtapp:setting
    id="entry_mode"
    label="<__trans phrase="Entry Mode">"
    hint=""
    show_hint="0">
			<select name="entry_mode">
				<option value="0"<TMPL_IF NAME=ENTRY_MODE_0> selected="selected"</TMPL_IF>>Off</option>
				<option value="1"<TMPL_IF NAME=ENTRY_MODE_1> selected="selected"</TMPL_IF>>Thumbs Up/Down</option>
				<option value="2"<TMPL_IF NAME=ENTRY_MODE_2> selected="selected"</TMPL_IF>>Star/Point Rating</option>
			</select>
			<p>Choose the mode to use for rating entries.</p><br />
</mtapp:setting>

<mtapp:setting
    id="entry_max_points"
    label="<__trans phrase="Entry Max Points">"
    hint=""
    show_hint="0">
			<select name="entry_max_points">
				<option value="1"<TMPL_IF NAME=ENTRY_MAX_POINTS_1> selected="selected"</TMPL_IF>>1</option>
				<option value="2"<TMPL_IF NAME=ENTRY_MAX_POINTS_2> selected="selected"</TMPL_IF>>2</option>
				<option value="3"<TMPL_IF NAME=ENTRY_MAX_POINTS_3> selected="selected"</TMPL_IF>>3</option>
				<option value="4"<TMPL_IF NAME=ENTRY_MAX_POINTS_4> selected="selected"</TMPL_IF>>4</option>
				<option value="5"<TMPL_IF NAME=ENTRY_MAX_POINTS_5> selected="selected"</TMPL_IF>>5</option>
				<option value="6"<TMPL_IF NAME=ENTRY_MAX_POINTS_6> selected="selected"</TMPL_IF>>6</option>
				<option value="7"<TMPL_IF NAME=ENTRY_MAX_POINTS_7> selected="selected"</TMPL_IF>>7</option>
				<option value="8"<TMPL_IF NAME=ENTRY_MAX_POINTS_8> selected="selected"</TMPL_IF>>8</option>
				<option value="9"<TMPL_IF NAME=ENTRY_MAX_POINTS_9> selected="selected"</TMPL_IF>>9</option>
				<option value="10"<TMPL_IF NAME=ENTRY_MAX_POINTS_10> selected="selected"</TMPL_IF>>10</option>
			</select>
			<p>Choose the maximum number of points or stars when rating entries.</p><br />
</mtapp:setting>
<TMPL_IF NAME=RATINGL_0>
<mtapp:setting
    id="comment_mode"
    label="<__trans phrase="Comment Mode">"
    hint=""
    show_hint="0">
			<select name="comment_mode">
				<option value="0"<TMPL_IF NAME=COMMENT_MODE_0> selected="selected"</TMPL_IF>>Off</option>
				<option value="1"<TMPL_IF NAME=COMMENT_MODE_1> selected="selected"</TMPL_IF>>Thumbs Up/Down</option>
				<option value="2"<TMPL_IF NAME=COMMENT_MODE_2> selected="selected"</TMPL_IF>>Star/Point Rating</option>
			</select>
			<p>Choose the mode to use for rating comments.</p><br />
</mtapp:setting>

<mtapp:setting
    id="comment_max_points"
    label="<__trans phrase="Comment Max Points">"
    hint=""
    show_hint="0">
			<select name="comment_max_points">
				<option value="1"<TMPL_IF NAME=COMMENT_MAX_POINTS_1> selected="selected"</TMPL_IF>>1</option>
				<option value="2"<TMPL_IF NAME=COMMENT_MAX_POINTS_2> selected="selected"</TMPL_IF>>2</option>
				<option value="3"<TMPL_IF NAME=COMMENT_MAX_POINTS_3> selected="selected"</TMPL_IF>>3</option>
				<option value="4"<TMPL_IF NAME=COMMENT_MAX_POINTS_4> selected="selected"</TMPL_IF>>4</option>
				<option value="5"<TMPL_IF NAME=COMMENT_MAX_POINTS_5> selected="selected"</TMPL_IF>>5</option>
				<option value="6"<TMPL_IF NAME=COMMENT_MAX_POINTS_6> selected="selected"</TMPL_IF>>6</option>
				<option value="7"<TMPL_IF NAME=COMMENT_MAX_POINTS_7> selected="selected"</TMPL_IF>>7</option>
				<option value="8"<TMPL_IF NAME=COMMENT_MAX_POINTS_8> selected="selected"</TMPL_IF>>8</option>
				<option value="9"<TMPL_IF NAME=COMMENT_MAX_POINTS_9> selected="selected"</TMPL_IF>>9</option>
				<option value="10"<TMPL_IF NAME=COMMENT_MAX_POINTS_10> selected="selected"</TMPL_IF>>10</option>
			</select>
			<p>Choose the maximum number of points or stars when rating entries.</p><br />
</mtapp:setting>

<mtapp:setting
    id="default_comment_threshold"
    label="<__trans phrase="Default Comment Threshold">"
    hint=""
    show_hint="0">
			<input name="comment_threshold" type="text" size="3" value="<TMPL_VAR NAME=COMMENT_THRESHOLD>"></input>&nbsp;
			<p>Advanced feature: choose the default rating or total score threshold for comments to be displayed.</p><br />
</mtapp:setting>
</TMPL_IF>
<mtapp:setting
    id="star_icon_width"
    label="<__trans phrase="Star Icon Width">"
    hint=""
    show_hint="0">
			<input name="unit_width" type="text" value="<TMPL_VAR NAME=UNIT_WIDTH>"></input>&nbsp;
			<p>Advanced feature: choose the width of the star icon. Default is 30.</p><br />
</mtapp:setting>
<mtapp:setting
    id="rebuild_after_vote"
    label="<__trans phrase="Rebuild After a Vote">"
    hint=""
    show_hint="0">
			<select name="rebuild">
				<option value="0"<TMPL_IF NAME=REBUILD_0> selected="selected"</TMPL_IF>>No Rebuilds</option>
				<option value="1"<TMPL_IF NAME=REBUILD_1> selected="selected"</TMPL_IF>>Rebuild Entry Only</option>
				<option value="2"<TMPL_IF NAME=REBUILD_2> selected="selected"</TMPL_IF>>Rebuild Entry, Archives, Indexes</option>
				<option value="3"<TMPL_IF NAME=REBUILD_3> selected="selected"</TMPL_IF>>Rebuild Indexes Only</option>
			</select>
			<p>Choose an option to rebuild pages after a vote is registered. You should only rebuild those pages where you are displaying ratings. WARNING: Rebuilding can affect performance on high-traffic sites with a lot of active voting.</p><br />
</mtapp:setting>
		<input name="ratingl" type="hidden" value="<TMPL_VAR NAME=RATINGL>"></input>
MT40
	}
	$tmpl;
}

sub rebuild_ar_templates {
	my ($app) = @_;
	my $blog_id = $app->param('blog_id');
	use MT::Template;
	my @tmpls = ("Ajax Rating Styles","Ajax Rating Javascript");
	foreach my $tmpl_name (@tmpls) {
		my $tmpl = MT::Template->load({ blog_id => $blog_id, name => $tmpl_name, type => 'index', rebuild_me => 0 });
		if ($tmpl) { 
			$app->rebuild_indexes( BlogID => $blog_id, Template => $tmpl, Force => 1 )
				or MT->log($app->errstr);
		}
	}
}
1;
