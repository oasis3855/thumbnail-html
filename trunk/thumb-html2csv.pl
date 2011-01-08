#!/usr/bin/perl

# Linux : save this file in << UTF-8  >> encode !
# Windows : save this file in << Shift-JIS  >> encode !
# ******************************************************
# Software name : Make Thumbnail HTML （サムネイルHTML作成）
#
# Copyright (C) INOUE Hirokazu, All Rights Reserved
#     http://oasis.halfmoon.jp/
#
# thumb-html2csv.pl
# version 0.1 (2010/December/14)
#
# GNU GPL Free Software
#
# このプログラムはフリーソフトウェアです。あなたはこれを、フリーソフトウェア財
# 団によって発行された GNU 一般公衆利用許諾契約書(バージョン2か、希望によっては
# それ以降のバージョンのうちどれか)の定める条件の下で再頒布または改変することが
# できます。
# 
# このプログラムは有用であることを願って頒布されますが、*全くの無保証* です。
# 商業可能性の保証や特定の目的への適合性は、言外に示されたものも含め全く存在し
# ません。詳しくはGNU 一般公衆利用許諾契約書をご覧ください。
# 
# あなたはこのプログラムと共に、GNU 一般公衆利用許諾契約書の複製物を一部受け取
# ったはずです。もし受け取っていなければ、フリーソフトウェア財団まで請求してく
# ださい(宛先は the Free Software Foundation, Inc., 59 Temple Place, Suite 330
# , Boston, MA 02111-1307 USA)。
#
# http://www.opensource.jp/gpl/gpl.ja.html
# ******************************************************

use strict;
use warnings;

use pQuery;
use HTML::Scrubber;
use HTML::TagParser;
use Text::CSV_XS;
use Time::Local;
use File::Basename;

my $strHTMLFilename = '';	# 入力ファイル（HTML）
my $strCsvFilename = '';	# 出力ファイル（CSV）
my $flag_copy_prev = 1;		#「 空白時、前行値のコピーを行う」スイッチ
my $flag_conv_time = 1;		#「日時をunix秒に変換する」スイッチ


print("\n".basename($0)." : HTML形式で保存されている写真管理データを、CSV形式にします\n".
	"（入力ファイルはこのスクリプトと同じエンコード形式の必要があります）\n\n");

# 初期値の入力（入出力ファイル名、選択肢など）
sub_user_input_init();

# HTMLを読み込んで CSVに書きだすメインルーチン
sub_parse_html();

print("処理終了\n");

exit();


# ユーザーによる初期値の入力
sub sub_user_input_init {

	# インポートする HTML ファイル名
	print("インポートするHTMLファイル名を入力 : ");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ die("終了（理由：ファイル名が入力されませんでした）\n"); }
	unless(-f $_){ die("終了（理由：ファイル ".$_." が存在しません）\n"); }
	$strHTMLFilename = $_;
	print("入力HTMLファイル名 : " . $strHTMLFilename . "\n");


	# エクスポートする CSV ファイル名
	print("出力するCSVファイル名を入力 : ");
	$_ = <STDIN>;
	chomp();
	if(length($_)<=0){ die("終了（理由：ファイル名が入力されませんでした）\n"); }
	if(-f $_ && -w $_){
		print("出力CSVファイル名（上書き） : " . $_ . "\n");
	}
	elsif(-f $_){
		die("終了（理由：出力CSVファイル " . $_ . " に書き込めません）\n");
	}
	else{
		print("出力CSVファイル名（新規作成） : " . $_ . "\n");
	}
	$strCsvFilename = $_;
	print("出力CSVファイル名 : " . $strCsvFilename . "\n");


	printf("空白項目は、前行の値をコピーしますか (Y/N) [Y] : ");
	$_ = <STDIN>;
	chomp;
	if(length($_)<=0){  $flag_copy_prev = 1; }
	elsif(uc($_) eq 'Y'){ $flag_copy_prev = 1; }
	else {$flag_copy_prev = 0; }

	printf("日時（YYYY/MM/DD<br />HH:MM）をunix秒に変換する (Y/N) [Y] : ");
	$_ = <STDIN>;
	chomp;
	if(length($_)<=0){  $flag_conv_time = 1; }
	elsif(uc($_) eq 'Y'){ $flag_conv_time = 1; }
	else {$flag_conv_time = 0; }

}


# HTMLファイルを読み込んで、CSVデータに切り分ける
sub sub_parse_html {

	my @arrCsvRaw = (); # CSV_XSに渡すCSV作成用の配列
	my @arrCsvPrevLine = ();	# 1行前のデータを保存する（空白桁補完用）
	my $flag_indata = 0;	# A LINKを検出したら1。この値が1の時、CSVデータ対象
	my $scrubber = HTML::Scrubber->new();
	$scrubber->allow(qw[ br ]);	# <br> タグは通過させる
	my $csv = Text::CSV_XS->new({binary=>1}); # 日本語の場合は binary を ON にする

	my $strTemp = undef;

	open(FH_OUT, ">$strCsvFilename") or die("CSVファイルに書き込めません\n");

	pQuery($strHTMLFilename)->find("tr")->each( sub{
		@arrCsvRaw = ();
		$flag_indata = 0;
		pQuery($_)->find("td")->each( sub{
			$strTemp = $_->innerHTML();
			$strTemp =~ s/\x0D\x0A|\x0D|\x0A/<br \/>/g; # 改行の除去
			$strTemp =~ s/\x09/\x20/g; # タブをスペースに変換
			$strTemp =~ s/\x20+/\x20/g; # 連続したスペースの統合

			# <td></td>間に通常の"文字列"が存在する場合
			if(length($scrubber->scrub($strTemp))>0){
				if($flag_indata == 1){
					# HTML文字列からタグを取り除く
					$strTemp = $scrubber->scrub($strTemp);

					# 文字列の調整
					$strTemp =~ s/　/ /g;	# 全角空白→半角空白
					$strTemp =~ s/<br><\/br>/<br>/g;		# ActivePerlの場合<br></br>→<br>
					$strTemp =~ s/[ ]*<br>[ ]*/<br>/g;		# <br>前後の空白文字を削除
					$strTemp =~ s/<br><br>|<br><br><br>/<br>/g;		# 連続<br>を1個に
					$strTemp =~ s/<br>$//g;		# 行末の<br>を除去
					$strTemp =~ s/^<br>//g;		# 行頭の<br>を除去
					if($strTemp eq ' '){ $strTemp = ''; }		# "空白1文字のみ"は切り捨て

					# 日時文字列をUNIX秒に変換
					if($flag_conv_time == 1)
					{
						my($strDate) = $strTemp;
						my($year,$mon,$day, $hour, $min) =
							($strDate =~ /(\d{4})\/(\d\d)\/(\d\d)<br>(\d\d):(\d\d)/);
						if(defined($year)){
	#						printf("%d/%d/%d %d:%d:00\n", $year,$mon,$day, $hour, $min);
							$strTemp = timelocal(0,$min,$hour,$day,$mon-1,$year)
						}
					}
#					push(@arrCsvRaw, $scrubber->scrub($strTemp));

					push(@arrCsvRaw, $strTemp);
				}
			}
			else {
				# A LINK が検出された場合（CSVは2データ扱い（LINK先とIMG SRCの二つ）
				if(length(GetAttribValue($strTemp, 'a', 'href'))>0){
					if($flag_indata == 1) {
						# 前のデータをフラッシュ（書き出す）
						$csv->combine(@arrCsvRaw);
						if($#arrCsvRaw > 1){ print(FH_OUT $csv->string()."\n"); }
						@arrCsvRaw = ();
						$flag_indata = 0;
					}
					push(@arrCsvRaw, GetAttribValue($strTemp, 'a', 'href'));
					if(length(GetAttribValue($strTemp, 'img', 'src'))>0){ push(@arrCsvRaw, GetAttribValue($strTemp, 'img', 'src')); }
					else{ push(@arrCsvRaw, ""); }
					$flag_indata = 1;	# A LINKを検出したフラグ
				}
				# IMG が検出された場合
				elsif(length(GetAttribValue($strTemp, 'img', 'src'))>0){
					if($flag_indata == 1) {
						push(@arrCsvRaw, GetAttribValue($strTemp, 'img', 'src'));
					}
				}
				# それ以外のタグが検出された場合は、空白データ扱い
				else{
					if($flag_indata == 1) {
						push(@arrCsvRaw, "");
					}
				}
			}
		});

		# 桁データが空白の場合、前行から値をコピーする
		if($flag_copy_prev == 1)
		{
			for(my $i=0; $i<$#arrCsvRaw; $i++)
			{
				if($arrCsvRaw[$i] eq '' && defined($arrCsvPrevLine[$i]) && length($arrCsvPrevLine[$i])>1)
				{
					$arrCsvRaw[$i] = $arrCsvPrevLine[$i];
				}
			}
			@arrCsvPrevLine = @arrCsvRaw;
		}

		$csv->combine(@arrCsvRaw);
		if($#arrCsvRaw > 1){ print(FH_OUT $csv->string()."\n"); }
	});

	close(FH_OUT);

}

#
# 引数：$strHTML, $strTagName, $strElementName
# 引数の例： '<img src="x.jpg">', 'img', 'src'
# 戻り値：$str（値が見つからないときは長さゼロの文字列）
# 戻り値の例：'x.jpg'
sub GetAttribValue
{
	my $html = HTML::TagParser->new();

	$html->parse("<html><body>".$_[0]."</body></html>");
	my $elem = $html->getElementsByTagName($_[1]);
	my $strValue = $elem->getAttribute($_[2]) if ref $elem;

	return($strValue) if defined $strValue;
	return("");
}

