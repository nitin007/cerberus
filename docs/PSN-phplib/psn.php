<?php 
/**
 * NOTE FROM MWAY:
 * There are 4 main functions that we need to use from this file.
 * 1) We need psn::get_jid(), to convert PSN ID (username) to a JID object (special username + region)
 * 2) We need psn::get_games(), to get a list of games associated with the provided JID
 * 3) We need psn::get_trophies(), to get a list of trophy IDs associated with the provided JID + game ID
 * 4) We need psn::getTrophyList(), to get a full list of trophy names and IDs for the specified game ID
 *
 * Important considerations:
 * - All responses are in XML.
 * - The first 3 functions are PSN endpoints and require authentication, either via psn::BasicLogin or psn::TrophyLogin
 * - The 4th endpoint does not require authentication, but is rate limited to 1 request per 3 seconds (I use 5 to be safe)
 * - get_jid(), get_games(), and get_trophies() are all POST requests, getTrophyList() is GET
 */

/* 
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: 
:: PSN Class v1.00                                       :: 
:: Author: DoSe                                          :: 
:: Contact: DoSe420@gmail.com                            :: 
:: Jun 9, 2011                                           :: 
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: 
*/ 

class psn 
{ 
   const FirmWare    = '3.70'; 
   const BasicLogin  = 'c7y-basic01:A9QTbosh0W0D^{7467l-n_>2Y%JG^v>o'; 
   const TrophyLogin = "c7y-trophy01:jhlWmT0|:0!nC:b:#x/uihx'Y74b5Ycx"; 

   public function __construct() 
   { 
       if(!function_exists('curl_init')) 
       { 
           throw new Exception('CURL is not installed'); 
       } 
   } 

   /* 
   ::::::::::::::::::::::::::::::::::::::::::::::::::: 
   :: 
   ::    Get JID 
   :: 
   */ 
   public function get_jid($psn) 
   { 
       if((isset($psn)) && (!empty($psn))) 
       { 
           $urls = array(  'us' => 'http://searchjid.usa.np.community.playstation.net/basic_view/func/search_jid', 
                           'gb' => 'http://searchjid.eu.np.community.playstation.net/basic_view/func/search_jid', 
                           'jp' => 'http://searchjid.jpn.np.community.playstation.net/basic_view/func/search_jid' 
           ); 

           $ch = curl_init(); 
           foreach($urls AS $key => $value) 
           { 
               curl_setopt($ch, CURLOPT_USERAGENT, "PS3Community-agent/1.0.0 libhttp/1.0.0"); 
               curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: text/xml; charset=UTF-8')); 
               curl_setopt($ch, CURLOPT_TIMEOUT, 10); 
               curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3); 
               curl_setopt($ch, CURLOPT_RETURNTRANSFER, true); 
               curl_setopt($ch, CURLOPT_URL, $value); 
               curl_setopt($ch, CURLOPT_POST, 1); 
               curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_DIGEST); 
               curl_setopt($ch, CURLOPT_USERPWD, self::BasicLogin); 
               curl_setopt($ch, CURLOPT_POSTFIELDS, "<?xml version='1.0' encoding='utf-8'?><searchjid platform='ps3' sv='" . self::FirmWare . "'><online-id>" . $psn . "</online-id></searchjid>"); 
               $data = curl_exec($ch); 
               $code = curl_getinfo($ch, CURLINFO_HTTP_CODE); 

               if((!empty($data)) && ($code == '200')) 
               { 
                   $xml = new SimpleXMLElement($data); 

                   if(!empty($xml->jid)) 
                   { 
                       curl_close($ch); 
                       return array('jid' => (string)$xml->jid, 'region' => (string)$key); 
                       break; 
                   } 
               } 
           } 
       } 
       return false; 
   } 

   /* 
   ::::::::::::::::::::::::::::::::::::::::::::::::::: 
   :: 
   ::    Get Profile 
   :: 
   */ 
   public function get_prof($region, $jid) 
   { 
       if((isset($region)) && (!empty($region)) && ((isset($jid)) && (!empty($jid)))) 
       { 
           $ch = curl_init(); 
           curl_setopt($ch, CURLOPT_USERAGENT, "PS3Community-agent/1.0.0 libhttp/1.0.0"); 
           curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: text/xml; charset=UTF-8')); 
           curl_setopt($ch, CURLOPT_TIMEOUT, 10); 
           curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3); 
           curl_setopt($ch, CURLOPT_RETURNTRANSFER, true); 
           curl_setopt($ch, CURLOPT_URL, "http://getprof." . $region . ".np.community.playstation.net/basic_view/func/get_profile"); 
           curl_setopt($ch, CURLOPT_POST, 1); 
           curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_DIGEST); 
           curl_setopt($ch, CURLOPT_USERPWD, self::BasicLogin); 
           curl_setopt($ch, CURLOPT_POSTFIELDS, "<profile platform='ps3' sv='" . self::FirmWare . "'><jid>" . $jid . "</jid></profile>"); 
           $data = curl_exec($ch); 
           $code = curl_getinfo($ch, CURLINFO_HTTP_CODE); 

           if((!empty($data)) && ($code == '200')) 
           { 
               $xml = new SimpleXMLElement($data); 

               if(!empty($xml)) 
               { 
                   $prof = array(); 
                   $array['name']    = (isset($xml->onlinename)) ? (string)$xml->onlinename : false; 
                   $array['country'] = (isset($xml->country))    ? (string)$xml->country : false; 
                   $array['aboutme'] = (isset($xml->aboutme))    ? (string)$xml->aboutme : false; 
                   $array['avatar']  = (isset($xml->avatarurl))  ? (string)$xml->avatarurl : (string)"http://static-resource.np.community.playstation.net/avatar/default/DefaultAvatar.png"; 
                   $array['color']   = (isset($xml->ucbgp))       ? (string)substr($xml->ucbgp, -8) : (string)"989898ff"; 
                   $array['psnplus'] = (isset($xml->plusicon))   ? (int)$xml->plusicon : 0; 
                   $prof[] = $array; 

                   curl_close($ch); 
                   return $prof; 
               } 
               curl_close($ch); 
               return false; 
           } 
           curl_close($ch); 
           return false; 
       } 
       return false; 
   } 

   /* 
   ::::::::::::::::::::::::::::::::::::::::::::::::::: 
   :: 
   ::    Get Overall Trophy Count 
   :: 
   */ 
   public function get_count($jid) 
   { 
       if((isset($jid)) && (!empty($jid))) 
       { 
           $ch = curl_init(); 
           curl_setopt($ch, CURLOPT_USERAGENT, "PS3Application libhttp/3.5.5-000 (CellOS)"); 
           curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: text/xml; charset=UTF-8')); 
           curl_setopt($ch, CURLOPT_TIMEOUT, 10); 
           curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3); 
           curl_setopt($ch, CURLOPT_RETURNTRANSFER, true); 
           curl_setopt($ch, CURLOPT_URL, "http://trophy.ww.np.community.playstation.net/trophy/func/get_user_info"); 
           curl_setopt($ch, CURLOPT_POST, 1); 
           curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_DIGEST); 
           curl_setopt($ch, CURLOPT_USERPWD, self::TrophyLogin); 
           curl_setopt($ch, CURLOPT_POSTFIELDS, "<nptrophy platform='ps3' sv='" . self::FirmWare . "'><jid>" . $jid . "</jid></nptrophy>"); 
           $data = curl_exec($ch); 
           $code = curl_getinfo($ch, CURLINFO_HTTP_CODE); 

           if((!empty($data)) && ($code == '200')) 
           { 
               $xml = new SimpleXMLElement($data); 

               if(!empty($xml)) 
               { 
                   $counts = array(); 
                   $array['points']     = (isset($xml->point))                   ? (int)$xml->point : false; 
                   $array['level']     = (isset($xml->level))                 ? (int)$xml->level : false; 
                   $array['base']        = (isset($xml->level['base']))         ? (int)$xml->level['base'] : false; 
                   $array['next']        = (isset($xml->level['next']))         ? (int)$xml->level['next'] : false; 
                   $array['progress']  = (isset($xml->level['progress']))  ? (int)$xml->level['progress'] : false; 
                   $array['platinum']  = (isset($xml->types['platinum']))  ? (int)$xml->types['platinum'] : false; 
                   $array['gold']        = (isset($xml->types['gold']))         ? (int)$xml->types['gold'] : false; 
                   $array['silver']     = (isset($xml->types['silver']))     ? (int)$xml->types['silver'] : false; 
                   $array['bronze']    = (isset($xml->types['bronze']))     ? (int)$xml->types['bronze'] : false; 
                   $array['total']     = ((isset($array['platinum'])) && (isset($array['gold'])) && (isset($array['silver'])) && (isset($array['bronze']))) ? (int)($array['platinum'] + $array['gold'] + $array['silver'] + $array['bronze']) : false; 
                   $counts[] = $array; 

                   curl_close($ch); 
                   return $counts; 
               } 
               curl_close($ch); 
               return false; 
           } 
           curl_close($ch); 
           return false; 
       } 
       return false; 
   } 

   /* 
   ::::::::::::::::::::::::::::::::::::::::::::::::::: 
   :: 
   ::    Get Users Games 
   :: 
   */ 
   public function get_games($jid) 
   { 
       if((isset($jid)) && (!empty($jid))) 
       { 
           $ch = curl_init(); 
           curl_setopt($ch, CURLOPT_URL, "http://trophy.ww.np.community.playstation.net/trophy/func/get_title_list"); 
           curl_setopt($ch, CURLOPT_USERAGENT, "PS3Application libhttp/3.5.5-000 (CellOS)"); 
           curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: text/xml; charset=UTF-8')); 
           curl_setopt($ch, CURLOPT_RETURNTRANSFER, true); 
           curl_setopt($ch, CURLOPT_USERPWD, self::TrophyLogin); 
           curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_DIGEST); 
           curl_setopt($ch, CURLOPT_POST, 1); 
           curl_setopt($ch, CURLOPT_TIMEOUT, 10); 
           curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3); 
           curl_setopt($ch, CURLOPT_POSTFIELDS, "<nptrophy platform='ps3' sv='" . self::FirmWare . "'><jid>" . $jid . "</jid><start>1</start><max>1</max></nptrophy>"); 
           $data = curl_exec($ch); 
           $code = curl_getinfo($ch, CURLINFO_HTTP_CODE); 

           $games = array(); 

           if((!empty($data)) && ($code == '200')) 
           { 
               $xml = new SimpleXMLElement($data); 
               $games['totalGames']      = (isset($xml->title)) ? (int)$xml->title : 0; 
               unset($xml); 

               for ($i = 1; $i < $games['totalGames']; $i += 64) 
               { 
                   curl_setopt($ch, CURLOPT_POSTFIELDS, "<nptrophy platform='ps3' sv='" . self::FirmWare . "'><jid>" . $jid . "</jid><start>" . $i . "</start><max>64</max></nptrophy>"); 

                   $data = curl_exec($ch); 
                   $code = curl_getinfo($ch, CURLINFO_HTTP_CODE); 
                   $data = str_replace("last-updated", "lastupdated", $data); 

                   if((!empty($data)) && ($code == '200')) 
                   { 
                       $xml = new SimpleXMLElement($data); 

                       if(!empty($xml)) 
                       { 
                           if(!isset($xml->list->info)) 
                           { 
                               break; 
                           } 

                           foreach($xml->list->info AS $key => $value) 
                           { 
                               $array['npcommid']       = (isset($value['npcommid']))           ? (string)$value['npcommid'] : false; 
                               $array['platinum']       = (isset($value->types['platinum'])) ? (int)$value->types['platinum'] : false; 
                               $array['gold']              = (isset($value->types['gold']))        ? (int)$value->types['gold'] : false; 
                               $array['silver']         = (isset($value->types['silver']))   ? (int)$value->types['silver'] : false; 
                               $array['bronze']         = (isset($value->types['bronze']))   ? (int)$value->types['bronze'] : false; 
                               $array['total']       = ((isset($array['platinum'])) && (isset($array['gold'])) && (isset($array['silver'])) && (isset($array['bronze']))) ? (int)($array['platinum'] + $array['gold'] + $array['silver'] + $array['bronze']) : false; 
                               $array['lastupdated'] = (isset($value->lastupdated))        ? strtotime($value->lastupdated) : 0; 

                               $games[] = $array; 
                           } 
                       } 
                   } 
               } 
           } 
           curl_close($ch); 
           return $games; 
       } 
       return false; 
   } 

   /* 
   ::::::::::::::::::::::::::::::::::::::::::::::::::: 
   :: 
   ::    Get Trophies 
   :: 
   */ 
   public function get_trophies($jid, $npcommid) 
   { 
       if((isset($jid)) && (!empty($jid)) && ((isset($npcommid)) && (!empty($npcommid)))) 
       { 
           $ch = curl_init(); 
           curl_setopt($ch, CURLOPT_URL, "http://trophy.ww.np.community.playstation.net/trophy/func/get_trophies"); 
           curl_setopt($ch, CURLOPT_USERAGENT, "PS3Application libhttp/3.5.5-000 (CellOS)"); 
           curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-Type: text/xml; charset=UTF-8')); 
           curl_setopt($ch, CURLOPT_RETURNTRANSFER, true); 
           curl_setopt($ch, CURLOPT_USERPWD, self::TrophyLogin); 
           curl_setopt($ch, CURLOPT_HTTPAUTH, CURLAUTH_DIGEST); 
           curl_setopt($ch, CURLOPT_POST, 1); 
           curl_setopt($ch, CURLOPT_TIMEOUT, 10); 
           curl_setopt($ch, CURLOPT_CONNECTTIMEOUT, 3); 
           curl_setopt($ch, CURLOPT_POSTFIELDS, "<nptrophy platform='ps3' sv='" . self::FirmWare . "'><jid>" . $jid . "</jid><list><info npcommid='" . $npcommid . "'><target>FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF</target></info></list></nptrophy>"); 
           $data = curl_exec($ch); 
           $code = curl_getinfo($ch, CURLINFO_HTTP_CODE); 

           if((!empty($data)) && ($code == '200')) 
           { 
               $xml = new SimpleXMLElement($data); 

               if(!empty($xml)) 
               { 
                   $trophyList = array(); 

                   $children = isset($xml->list->info->trophies) ? $xml->list->info->trophies->children() : array();

                   foreach($children as $key => $value) 
                   { 
                       $array['id'] = (int)$value['id']; 

                       switch($value['type']) 
                       { 
                           case 0: 
                               $array['type'] = "bronze"; 
                           break; 

                           case 1: 
                               $array['type'] = "silver"; 
                           break; 

                           case 2: 
                               $array['type'] = "gold"; 
                           break; 

                           case 3: 
                               $array['type'] = "platinum"; 
                           break; 
                       } 

                       $array['trophydate'] = strtotime($value); 
                       $trophyList[] = $array; 
                   } 
                   curl_close($ch); 
                   return $trophyList; 
               } 
               curl_close($ch); 
               return false; 
           } 
           curl_close($ch); 
           return false; 
       } 
       return false; 
   }

    public function getTrophyList($npcommid) {
      $url = "http://www.psnapi.com.ar/ps3/api/psn.asmx/getListTrophies?sGameId={$npcommid}"; 
      $uas = array(
        'PS3Community-agent/1.0.0 libhttp/1.0.0',
        'Mozilla/5.0 (PLAYSTATION 3; 3.55)',
        'Mozilla/5.0 (PLAYSTATION 3; 2.00)',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/27.0.1453.93 Safari/537.36'
      );
          
      $ch = curl_init();  
          
      curl_setopt($ch, CURLOPT_URL, $url); 
      curl_setopt($ch, CURLOPT_RETURNTRANSFER, true); 
      curl_setopt($ch, CURLOPT_TIMEOUT, 15); 
      curl_setopt($ch, CURLOPT_USERAGENT, $uas[rand(0, count($uas) - 1)]);
          
      $data = curl_exec($ch); 
      $code = curl_getinfo($ch, CURLINFO_HTTP_CODE); 

      #echo '================================================================================' . PHP_EOL;
      #echo $data . PHP_EOL;
      #echo '================================================================================' . PHP_EOL;

      if((!empty($data)) && ($code == '200')) 
      { 
          $xml = new SimpleXMLElement($data); 

          if(!empty($xml)) 
          { 
              $trophyList = array(); 

              $children = isset($xml->Trophy) ? $xml->children() : array();

              if(!count($children)) {
                return $trophyList;
              }

              foreach($children as $key => $value) 
              { 
                  if(strtolower($value->Platform) !== 'ps3') {
                    die('Ignoring platform: ' . $value->Platform . PHP_EOL);
                    continue;
                  }

                  $array          = array();
                  $array['id']    = (int)$value->IdTrophy; 
                  $array['type']  = strtolower($value->TrophyType);
                  $array['title'] = (string)$value->Title;
                  $array['desc']  = (string)$value->Description;
                  $array['image'] = (string)$value->Image;

                  $trophyList[(int)$value->IdTrophy] = $array; 
              } 

              curl_close($ch); 
              return $trophyList; 
          } 
          return false; 
      } 
          
      return array(); 
    } 
} 

?> 
